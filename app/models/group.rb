class Group < ActiveRecord::Base
  # extend ActiveSupport::Memoizable

  MAX_USERS = 500
  COMMENT_MAX_CHARS = 2000

  # Associations
  has_many :users
  belongs_to :owner, class_name: "User"
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :group_invites, dependent: :destroy, inverse_of: :group

  acts_as_taggable

  # Callbacks
  before_create :generate_key
  after_create :associate_owner

  validates :name, presence: true


  scope :having_more_users_than, lambda {|number|
    group_ids = User.select("group_id").
      group("group_id").
      having("count(*) > ?", [ number ])
    where(id: group_ids)
  }

  scope :with_readings_in_last_30_days, -> {
    group_ids = Group.includes(users: :readings).where('readings.created_at >= ?', 30.days.ago).pluck(:id)
    where(id: group_ids)
  }
  scope :active_in_30_days, -> { joins(users: :readings).where('readings.created_at >= ?', 30.days.ago).select{|g| g.readings.count >= 1}.uniq }
  scope :active, -> { joins(users: :readings).where('readings.created_at >= ?', 7.days.ago).select{|g| g.readings.count >= 1}.uniq }

  def readings
    Reading.joins(:user).where("users.group_id = ?", id)
  end

  def pending_group_invites
    group_invites.where(status: GroupInvite.statuses['invited'])
  end

  def generate_key!
    generate_key
    save
  end

  def add_user(user)
    return false unless users.count < MAX_USERS
    users << user
    user.update_attribute "joined_group_on", Date.today
  end

  def randomize_owner!
    current_users = self.users
    destroy and return false if current_users.length == 0
    begin
      new_user = current_users.sort_by { rand }.first
    end while self.owner == new_user
    self.owner_id = new_user.id
    save!
  end

  def score(date_from = 6.days.ago, date_to = Time.now.utc)
    cache_identifier = "#{id}-#{date_from}-#{date_to}"

    Rails.cache.fetch(cache_identifier, expires_in: 1.hour) do
      date_from = Time.zone.parse(date_from) if date_from.is_a? String
      date_to   = Time.zone.parse(date_to) if date_to.is_a? String
      (users.inject(0) do |sum, user|
        sum + user.consistency(date_from, date_to)
      end / users.length.to_f * 100).to_i
    end
  end

  def average_user_readings(since, to = Time.now)
    since = Time.zone.parse(since) if since.is_a? String
    to    = Time.zone.parse(to) if to.is_a? String

    readings.since(since).until(to).count / users.count.to_f
  end

  def average_user_consistency(since, to = Time.now.utc)
    since = Time.zone.parse(since) if since.is_a? String
    to    = Time.zone.parse(to) if to.is_a? String
    sum = users.inject(0) do |result, user|
      result + user.consistency(since, to)
    end
    sum / users.count.to_f
  end

  def send_weekly_email
    past_week_stats = find_group_stats(7.days.ago, Time.now)
    users.where(send_monthly_report: true).each{|user| UsersNotifier.send_weekly_group_stats(user, past_week_stats).deliver_now}
  end

  def find_group_stats(from_date, to_date)
    weekly_stats = {}
    weekly_stats[:group_name]     = name
    weekly_stats[:users_readings] = Reading.where(created_at: from_date..to_date, user: users).group(:user).count
    weekly_stats[:total_reading]  = weekly_stats[:users_readings].values.sum
    weekly_stats[:average]        = (weekly_stats[:total_reading]/users.count.to_f).round 1
    weekly_stats[:top_reader]     = weekly_stats[:users_readings].key(weekly_stats[:users_readings].values.max).name
    weekly_stats
  end

  private

  def associate_owner
    add_user(owner)
    owner.group = self
  end

  def generate_key
    begin
      self.key = (0...6).map{65.+(rand(25)).chr}.join
    end while Group.find_by(key: self.key)
  end
end
