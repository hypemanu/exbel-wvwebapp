class Comment < ActiveRecord::Base

  COMMENT_MAX_CHARS = 2000

  include ActionView::Helpers::DateHelper

  belongs_to :user
  belongs_to :commentable, polymorphic: true

  has_many :comments, -> {order(:created_at)}, as: :commentable

  validates :user, presence: true
  validates :content, presence: true
  validates :commentable, presence: true

  validate :commentable_belongs_to_user
  validate :content_limit

  scope :public_comments, -> { where(commentable_type: 'User') }

  def self.recent_first
    order('created_at desc')
  end

  def self.recent_last
    order(:created_at)
  end

  def to_json_for_react
    Jbuilder.new do |comment|
      comment.id id
      comment.content content
      comment.timeAgo timeAgo
      comment.user user.to_json_for_react
      comment.comments comments.map{|c| c.to_json_for_react.attributes! }
    end
  end

  private

  def timeAgo
    time_ago_in_words(created_at) + " ago"
  end

  def content_limit
    if commentable
      char_limit = commentable.class::COMMENT_MAX_CHARS
      errors.add(:base, "The maximum comment limit is #{char_limit}") if content.length > char_limit
    end
  end

  def commentable_belongs_to_user
    if not check_user_permission(commentable)
      errors.add(:base, "You cannot comment upon something that you are not related to")
    end
  end

  def check_user_permission(commentable)
    case commentable.class.to_s
      when "Group"
        commentable.users.include?(user)
      when "Comment"
        check_user_permission(commentable.commentable) # call recursively
      when "Chapter"
        User.all.include?(user)
      when "User"
        User.all.include?(user)
      else
        false
    end
  end
end