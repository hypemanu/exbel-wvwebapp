# class User < ApplicationRecord
#   # Include default devise modules. Others available are:
#   # :confirmable, :lockable, :timeoutable and :omniauthable
#   devise :database_authenticatable, :registerable, :recoverable, :trackable, :validatable

#   has_many :chapters, through: :readings
#   has_one :own_group, class_name: "Group", foreign_key: "owner_id"
#   belongs_to :group
# end
class User < ActiveRecord::Base

  MAX_USERS = 500
  COMMENT_MAX_CHARS = 2000

  # Devise integration
  devise :database_authenticatable, :registerable, :validatable, :recoverable#, :omniauthable, omniauth_providers: [:facebook, :google_oauth2]
  # Associations

  # has_attached_file :avatar, styles: { medium: "300x300>", thumb: "32x32>" }, storage: :s3, s3_credentials: Rails.root.join("config/s3.yml")

  has_many :readings, dependent: :destroy do
    def build_bulk(fragment)
      chapters = Chapter.search(fragment)
      if chapters.any?
        chapters.each do |chapter|
          build(chapter: chapter)
        end
        chapters
      else
        false
      end
    end

    def create_bulk(fragment)
      if chapters = build_bulk(fragment)
        @association.owner.save
        chapters
      else
        false
      end
    end
  end
  has_many :chapters, through: :readings
  has_one :own_group, class_name: "Group", foreign_key: "owner_id"
  belongs_to :group
  has_many :all_comments, class_name: 'Comment'
  has_many :comments, as: :commentable, dependent: :destroy

  validates_associated :readings

  # validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\Z/

  validates :name, presence: true
  scope :by_phone_number, lambda {|phone_number|
    phone_number = phone_number.gsub(/.*(\d{3})(\d{3})(\d{4})$/, "(\\1) \\2-\\3")
    where(phone_number: phone_number)
  }

  # after_create :attach_avatar

  def can_predict_next_reading?
    readings = self.readings.includes(:chapter).last(3)
    return nil unless readings.count == 3 && readings.map{|r| r.chapter.book_id}.uniq.count == 1
    r = readings.first.chapter_id
    last_readings_in_sequence = readings.map{|r| r.chapter_id} == [r, r+1, r+2]
    prediction =  last_readings_in_sequence && is_next_chapter_from_same_book?(readings.last.chapter_id)
  end

  def is_next_chapter_from_same_book?(chapter_id)
    Chapter.where(id: [chapter_id, chapter_id+1]).pluck(:book_id).uniq.count == 1
  end

  def next_chapter
    Chapter.find(readings.last.chapter.id+1)
  end

  def attach_avatar
    unless self.avatar_file_name?
      new_avatar = Avatarly.generate_avatar(self.name || self.email)
      self.avatar = StringIO.new(new_avatar)
      self.avatar_file_name = 'avatarly.png'
      self.save
    end
  end

  def self.inactive
     ids = joins(:readings).select("users.id, max(readings.created_at)").
       group("users.id").having("max(readings.created_at) < ?", 30.days.ago).pluck('users.id')
     find(ids)
   end

  def self.inactive_for(num_days)
     ids = joins(:readings).select("users.id, max(readings.created_at)").group("users.id").having("max(readings.created_at) < ?", num_days.days.ago).pluck('users.id')
     find(ids)
  end

  class << self
    def create_with_omniauth(auth)
      user = User.find_by(email: auth["info"]["email"]) || create! do |user|
        user.provider  = auth["provider"]
        user.uid       = auth["uid"]
        user.name      = auth["info"]["name"] == auth["info"]["email"]? auth["info"]["email"].first.capitalize : auth["info"]["name"]
        user.email     = auth["info"]["email"]
        user.image_url = auth["info"]["image"]
        generated_password = Devise.friendly_token.first(8)
        user.password  = generated_password
        user.skip_confirmation! unless auth["confirmed_email"] == "Unconfirmed"
      end
      return user
    end

    def ungroup_inactive_users
      inactive_pairs_of_users_and_groups = inactive.map {|user| {user: user, group: user.group} if user.group_id?}.compact
      where(id: inactive.map(&:id)).update_all(group_id: nil)
      inactive_pairs_of_users_and_groups.each do |pair|
        # UsersNotifier.delay.ungroup_inactive_user_notification(pair[:user], pair[:group])
        UsersNotifier.ungroup_inactive_user_notification(pair[:user], pair[:group]).deliver_now
      end
    end

    def notify_almost_inactive_users
      # inactive_for(29).each {|user| UsersNotifier.delay.automatically_removal_notification(user) }
      inactive_for(29).each {|user| UsersNotifier.automatically_removal_notification(user).deliver_now }
    end

    def notify_15_days_inactive_users
      # inactive_for(15).each {|user| UsersNotifier.delay.dont_give_up_notification(user) }
      inactive_for(15).each {|user| UsersNotifier.dont_give_up_notification(user).deliver_now }
    end
  end

  def leave_group!
    return unless self.group
    current_group_id, current_group_owner = self.group.id, self.group.owner
    if ((self == current_group_owner) && (self.group.users.count == 1)) || self != current_group_owner
      self.group_id = nil
      self.joined_group_on = nil
      save!
    else
      errors.add(:group, 'You need to transfer the ownership to other member before leaving the group.')
    end
  end

  def unique_readings(date_from, date_to)
    readings
    .select("distinct on (day) to_char(date_read, 'YYYYMMDD') as day,id")
    .where("readings.date_read >= ?", [date_from])
    .where("readings.date_read <= ?", [date_to])
  end

  def consistency(date_from = 6.days.ago.utc, date_to = Time.now.utc)
    reading_days = unique_readings(date_from.to_date, date_to.to_date).length
    date_range = (date_to.to_date + 1.day - date_from.to_date).to_i
    reading_days.to_f / (date_range == 0 ? 1 : date_range).abs
  end
  # memoize :consistency

  def last_activity_day
    readings.any? ? readings.last.created_at : "Never"
  end

  def completeness
    chapters.count.to_f / Chapter.count
  end

  def latest_reading
    readings.order("created_at DESC").first
  end

  def is_inactive?
    readings.order("date_read DESC").first.date_read < 30.days.ago.to_date
  end

  def update_last_read_in_group
    group.update(last_read_on: Date.today) if group
  end

  def avatar_url(size = 'thumb')
    avatar.url(size.to_sym)
  end

  def to_json_for_react
    Jbuilder.new do |user|
      user.(self, :id, :name, :avatar_url)
    end
  end
end
