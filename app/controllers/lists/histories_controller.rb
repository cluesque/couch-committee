class Lists::HistoriesController < ApplicationController
  def show
    @list = Current.user.lists.find(params[:list_id])
    @events = @list.history
  end
end
