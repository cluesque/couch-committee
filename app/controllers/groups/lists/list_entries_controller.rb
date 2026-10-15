class Groups::Lists::ListEntriesController < ApplicationController
  include SetCurrentGroup

  before_action :set_list

  def show
    @entry = @list.list_entries.includes(:viewings, title: :episodes).find(params[:id])
    @active_entry = @list.list_entries.active.find_by(title_id: @entry.title_id) unless @entry.active?
  end

  def new
    @query = params[:q].to_s.strip
    @titles = @query.present? ? Title.search(@query).limit(25) : Title.none
    @active_title_ids = @list.list_entries.active.pluck(:title_id)
  end

  def create
    title = Title.find(params.expect(:title_id))
    entry = @list.add(title)

    if entry.persisted?
      again = " again" if @list.list_entries.where(title: title).where.not(id: entry.id).exists?
      redirect_to [ Current.group, @list ], notice: "Added #{title.full_name}#{again}."
    else
      redirect_to new_group_list_list_entry_path(Current.group, @list, q: params[:q]),
        alert: "#{title.full_name} #{entry.errors[:title].to_sentence}."
    end
  end

  def reorder
    @list.reorder(params.expect(list_entry_ids: []))
    head :no_content
  end

  private
    def set_list
      @list = Current.group.lists.find(params[:list_id])
    end
end
