# Tagging an entry, in place on its page: toggle the list's tags, or make a new one.
class Lists::ListEntries::TagsController < ApplicationController
  before_action :set_list_entry

  def edit
    @selected_ids = @list_entry.tag_ids
    @new_tag = Tag.new(list: @list, color: Tag.next_color(@list))
  end

  def update
    tags = @list.tags.where(id: params.dig(:list_entry, :tag_ids)).to_a
    # Built apart from @list.tags, so the form doesn't offer it as one of the list's tags to tick.
    @new_tag = Tag.new(list: @list, name: params.dig(:new_tag, :name).to_s, color: params.dig(:new_tag, :color))

    if @new_tag.name.present?
      unless @new_tag.save
        @selected_ids = tags.map(&:id)
        return render :edit, status: :unprocessable_content
      end
      tags << @new_tag
    end

    @list_entry.tags = tags
    redirect_to [ @list, @list_entry ], notice: "Saved."
  end

  private
    def set_list_entry
      @list = Current.user.lists.find(params[:list_id])
      @list_entry = @list.list_entries.find(params[:list_entry_id])
    end
end
