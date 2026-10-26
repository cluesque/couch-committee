# Renaming, recoloring, and deleting a list's tags, in place on the list's edit page. They're made
# (and put on entries) from an entry's page.
class Lists::TagsController < ApplicationController
  before_action :set_tag

  def edit
  end

  def update
    if @tag.update(params.expect(tag: [ :name, :color ]))
      redirect_to edit_list_path(@list), notice: "Saved #{@tag.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tag.destroy!
    redirect_to edit_list_path(@list), notice: "Deleted #{@tag.name}.", status: :see_other
  end

  private
    def set_tag
      @list = Current.user.lists.find(params[:list_id])
      @tag = @list.tags.find(params[:id])
    end
end
