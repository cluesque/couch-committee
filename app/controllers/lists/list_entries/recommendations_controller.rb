class Lists::ListEntries::RecommendationsController < ApplicationController
  before_action :set_list_entry

  def edit
  end

  def update
    if @list_entry.update(recommendation: params.dig(:list_entry, :recommendation))
      redirect_to [ @list, @list_entry ], notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_list_entry
      @list = Current.user.lists.find(params[:list_id])
      @list_entry = @list.list_entries.find(params[:list_entry_id])
    end
end
