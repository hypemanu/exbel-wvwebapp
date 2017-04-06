class ExbelStat < ActiveRecord::Base

  def self.update_now!
    groups = Group.having_more_users_than(0).includes(users: :readings)
    groups = groups.sort { |x,y| y.score <=> x.score }
    exbel_stats = ExbelStat.last ? ExbelStat.last : ExbelStat.new
    exbel_stats.msg_in_24hr = Reading.where('created_at >= ?', 24.hours.ago).count
    exbel_stats.total_users = User.count
    exbel_stats.total_groups = Group.count
    exbel_stats.msg_in_7d = Reading.where("date_read >= ?", 7.days.ago).count
    exbel_stats.msg_in_30d = Reading.where("date_read >= ?", 30.days.ago).count
    exbel_stats.top_chapter = Chapter.most_read ? Chapter.most_read.title : 'No readings'
    # top_reading_group = groups.max{ |a,b| a.average_user_readings(7.days.ago) <=> b.average_user_readings(7.days.ago) }
    since_date = 7.days.ago.to_formatted_s(:db)
    until_date = Time.now.to_formatted_s(:db)
    r = Reading.find_by_sql <<-EOF
      select g_id, r_count, u_count, (r_count / u_count) as average
      from (
        select g_id, max(r_count) as r_count, count(user_id) as u_count
        from (
          select g_id, r_count, users.id as user_id
          from (
            select g_id, count(r_id) as r_count
            from (
              select users.group_id as g_id, readings.id as r_id
              from users inner join readings
              on users.id = readings.user_id
              where users.group_id is not null
              and readings.created_at > '#{since_date}'
              and readings.created_at <= '#{until_date}'
            ) as foo
            group by g_id
          ) as bar inner join users on bar.g_id = users.group_id
        ) as baz
        group by baz.g_id
      ) as fuu
      order by average desc limit 1;
    EOF
    top_reading_group = Group.find r[0].g_id rescue nil
    exbel_stats.top_group = top_reading_group ? top_reading_group.name : 'No group'
    exbel_stats.updated_at = Time.now
    exbel_stats.save
    p "Updated Stats - msg_in_24hr: #{exbel_stats.msg_in_24hr}, total_users: #{exbel_stats.total_users}, total_groups: #{exbel_stats.total_groups}, msg_in_7d: #{exbel_stats.msg_in_7d}, msg_in_30d: #{exbel_stats.msg_in_30d}, top_chapter: #{exbel_stats.top_chapter}, top_group: #{exbel_stats.top_group}"
  end
end
