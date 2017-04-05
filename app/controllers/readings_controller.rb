class ReadingsController < ApplicationController
  # before_action :authenticate_user!

  def index
    # @readings = current_user.readings
  end

  def create
    if chapter = current_user.readings.create_bulk(params[:fragment])
      current_user.update_last_read_in_group
      success_flash_for(chapter)
      flash[:success] = "Successfully submitted #{chapter.title}"
    else
      flash[:error] = "No matches for #{fragment.inspect}"
    end
    respond_to do |format|
      format.html{ redirect_to root_path }
    end
  end

  def new
    @reading = Reading.new
  end

  def destroy
  end
end
