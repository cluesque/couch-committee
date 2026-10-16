class Groups::Lists::ListEntries::RecommendationsController < ApplicationController
  include SetCurrentGroup

  before_action :set_list_entry

  def edit
  end

  def update
    if @list_entry.update(recommendation: params.dig(:list_entry, :recommendation))
      redirect_to [ Current.group, @list, @list_entry ], notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_list_entry
      @list = Current.group.lists.find(params[:list_id])
      @list_entry = @list.list_entries.find(params[:list_entry_id])
    end
end
