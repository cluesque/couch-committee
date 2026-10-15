class Groups::Lists::HistoriesController < ApplicationController
  include SetCurrentGroup

  def show
    @list = Current.group.lists.find(params[:list_id])
    @events = @list.history
  end
end
