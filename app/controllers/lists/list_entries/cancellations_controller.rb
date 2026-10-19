class Lists::ListEntries::CancellationsController < ApplicationController
  before_action :set_list_entry

  def new
  end

  def create
    @list_entry.cancel(note: params.dig(:cancellation, :note))
    redirect_to @list, notice: "Removed #{@list_entry.title.full_name} from #{@list.name}."
  end

  private
    def set_list_entry
      @list = Current.user.lists.find(params[:list_id])
      @list_entry = @list.list_entries.active.find(params[:list_entry_id])
    end
end
