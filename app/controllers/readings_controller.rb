class ReadingsController < ApplicationController
  layout "users"
  before_action :authenticate_user!

  def index
    @readings = current_user.readings
  end

  def create
    if chapter = current_user.readings.create_bulk(params[:fragment])
      # current_user.update_last_read_in_group
      flash[:success] = "Successfully submitted #{chapter.map(&:title).to_sentence}"
    else
      flash[:error] = "No matches for #{params[:fragment].inspect}"
    end
    respond_to do |format|
      format.html{ redirect_to root_path }
    end
  end

  def new
    @reading = Reading.new
  end

  def destroy
    @reading = current_user.readings.find_by(id: params[:id])
    @reading.destroy if @reading
    flash[:success] = "Successfully removed #{@reading.chapter.title}"
    respond_to do |format|
      format.html{ redirect_to root_path }
    end
  end

  def dashboard
    load_dashboard_related_items    
  end

  private

  def load_dashboard_related_items
    @reading_stats = find_all_stats_for_current_user
    @readings = current_user.readings.order("created_at DESC").includes(:chapter).limit(5)
  end

  def find_all_stats_for_current_user
    stats = {}
    stats[:total_reading] = current_user.readings.select('distinct on (chapter_id) *').length
    stats[:total_remaining] = Chapter.count - current_user.readings.select('distinct on (chapter_id) *').length
    stats[:complete_percent] = (stats[:total_reading]*100/Chapter.count.to_f).round(1)
    stats[:remaining_percent] = (stats[:total_remaining]*100/Chapter.count.to_f).round(1)
    last_month_readings = current_user.readings.where('created_at > ? AND created_at <= ?', 1.month.ago, Time.now).count
    stats[:days_to_complete] = last_month_readings > 0 ? find_time_to_complete(stats[:total_remaining],last_month_readings) : "&infin;"
    stats
  end

  def find_time_to_complete(remaining_count, last_month_readings)
    total_days = (remaining_count/last_month_readings*30)
    distance_of_time_in_words(Date.today, total_days.days.from_now, options = {})
  end

  def distance_of_time_in_words(from_time, to_time = 0, options = {})
    options = {
      scope: :'datetime.distance_in_words'
    }.merge!(options)

    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    from_time, to_time = to_time, from_time if from_time > to_time
    distance_in_minutes = ((to_time - from_time)/60.0).round
    distance_in_seconds = (to_time - from_time).round

    I18n.with_options :locale => options[:locale], :scope => options[:scope] do |locale|
      case distance_in_minutes
        when 0..1
          return distance_in_minutes == 0 ?
            locale.t(:less_than_x_minutes, :count => 1) :
            locale.t(:x_minutes, :count => distance_in_minutes) unless options[:include_seconds]

          case distance_in_seconds
            when 0..4   then locale.t :less_than_x_seconds, :count => 5
            when 5..9   then locale.t :less_than_x_seconds, :count => 10
            when 10..19 then locale.t :less_than_x_seconds, :count => 20
            when 20..39 then locale.t :half_a_minute
            when 40..59 then locale.t :less_than_x_minutes, :count => 1
            else             locale.t :x_minutes,           :count => 1
          end

        when 2...45           then locale.t :x_minutes,      :count => distance_in_minutes
        when 45...90          then locale.t :about_x_hours,  :count => 1
        # 90 mins up to 24 hours
        when 90...1440        then locale.t :about_x_hours,  :count => (distance_in_minutes.to_f / 60.0).round
        # 24 hours up to 42 hours
        when 1440...2520      then locale.t :x_days,         :count => 1
        # 42 hours up to 30 days
        when 2520...43200     then locale.t :x_days,         :count => (distance_in_minutes.to_f / 1440.0).round
        # 30 days up to 60 days
        when 43200...86400    then locale.t :about_x_months, :count => (distance_in_minutes.to_f / 43200.0).round
        # 60 days up to 365 days
        when 86400...525600   then locale.t :x_months,       :count => (distance_in_minutes.to_f / 43200.0).round
        else
          if from_time.acts_like?(:time) && to_time.acts_like?(:time)
            fyear = from_time.year
            fyear += 1 if from_time.month >= 3
            tyear = to_time.year
            tyear -= 1 if to_time.month < 3
            leap_years = (fyear > tyear) ? 0 : (fyear..tyear).count{|x| Date.leap?(x)}
            minute_offset_for_leap_year = leap_years * 1440
            # Discount the leap year days when calculating year distance.
            # e.g. if there are 20 leap year days between 2 dates having the same day
            # and month then the based on 365 days calculation
            # the distance in years will come out to over 80 years when in written
            # English it would read better as about 80 years.
            minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year
          else
            minutes_with_offset = distance_in_minutes
          end
          remainder                   = (minutes_with_offset % 525600)
          distance_in_years           = (minutes_with_offset.div 525600)
          if remainder < 131400
            locale.t(:about_x_years,  :count => distance_in_years)
          elsif remainder < 394200
            locale.t(:over_x_years,   :count => distance_in_years)
          else
            locale.t(:almost_x_years, :count => distance_in_years + 1)
          end
      end
    end
  end
end

