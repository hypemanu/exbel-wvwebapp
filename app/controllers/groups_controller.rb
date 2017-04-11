class GroupsController < ApplicationController
  layout "users"
  before_action :authenticate_user!

  def my_group
    @group = current_user.group
    if @group
      @group_members = @group.group_invites.where(status: GroupInvite.statuses['invited']) + @group.users.includes(readings: :chapter)
      @group_members.map! do |m|
        {
          name: m.name,
          email: m.email,
          id: m.id,
          type: m.class.name,
          joined: (m.class.name == 'User' ? m.joined_group_on.strftime('%b %d, %Y') : 'Not Yet'),
          msgs_read: (m.class.name == 'User' ? m.readings.since(30.days.ago).count : '--'),
          last_activity: (m.try(:last_activity_day) || '--'),
          last_reading: (m.try(:readings).try(:last).try(:chapter).try(:title) || '--')
        }
      end
      @group_members = @group_members.sort_by!{|x| x[:name].try(:downcase)}
    end
  end

  def create
    group = current_user.build_own_group(group_params)
    if group.save
      # current_user.update_last_read_in_group
      flash[:success] = "Successfully created group #{group.name}"
    else
      flash[:error] = "Not able to create the group"
    end
    respond_to do |format|
      format.html{ redirect_to my_group_path }
    end
  end

  private

  def group_params
    params.require(:group).permit(:name, :tag_list)
  end
end
