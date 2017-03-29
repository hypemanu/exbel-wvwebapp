class Reading < ActiveRecord::Base

  belongs_to :user
  belongs_to :chapter

  validates_presence_of :user, :chapter
  validates_uniqueness_of :chapter, :scope => :user

  delegate :name, to: :chapter, prefix: true

  scope :since, lambda {|date|
    return unless date.is_a? Time or date.respond_to?(:to_time)
    where("readings.created_at > ?", [ date.to_time ])
  }

  scope :until, lambda {|date|
    return unless date.is_a? Time or date.respond_to?(:to_time)
    where("readings.created_at <= ?", [ date.to_time ])
  }


  scope :on, lambda {|date|
    return unless date.is_a? Time
    start_date = date.beginning_of_day
    end_date = date.end_of_day
    where("readings.created_at > :start and readings.created_at < :end",
          start: start_date, end: end_date)
  }

  scope :latest_by_unique_users, lambda {|limit|
    where(id: select("max(readings.id)").group("readings.user_id"))
    .order("readings.created_at DESC")
    .limit(limit)
  }

  after_create :adjust_date_read

  private

  def adjust_date_read
    time_zone = ActiveSupport::TimeZone[user.timezone] || Time.zone
    self.date_read = (self.created_at + time_zone.utc_offset).to_date
    save
  end
end
