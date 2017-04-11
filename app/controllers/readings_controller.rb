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
    
  end
end
