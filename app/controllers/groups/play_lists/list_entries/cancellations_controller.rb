class Groups::PlayLists::ListEntries::CancellationsController < ApplicationController
  include SetCurrentGroup

  before_action :set_list_entry

  def new
  end

  def create
    @list_entry.cancel(note: params.dig(:cancellation, :note))
    redirect_to [ Current.group, @play_list ], notice: "Cancelled #{@list_entry.title.full_name}."
  end

  private
    def set_list_entry
      @play_list = Current.group.play_lists.find(params[:play_list_id])
      @list_entry = @play_list.list_entries.active.find(params[:list_entry_id])
    end
end
