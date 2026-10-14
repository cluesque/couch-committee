class Groups::PlayLists::HistoriesController < ApplicationController
  include SetCurrentGroup

  def show
    @play_list = Current.group.play_lists.find(params[:play_list_id])
    @entries = @play_list.history
  end
end
