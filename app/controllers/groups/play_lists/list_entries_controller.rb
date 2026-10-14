class Groups::PlayLists::ListEntriesController < ApplicationController
  include SetCurrentGroup

  before_action :set_play_list

  def show
    @entry = @play_list.list_entries.includes(:viewings, title: :episodes).find(params[:id])
  end

  def new
    @query = params[:q].to_s.strip
    @titles = @query.present? ? Title.search(@query).limit(25) : Title.none
    @active_title_ids = @play_list.list_entries.active.pluck(:title_id)
  end

  def create
    title = Title.find(params.expect(:title_id))
    entry = @play_list.add(title)

    if entry.persisted?
      redirect_to [ Current.group, @play_list ], notice: "Added #{title.full_name}."
    else
      redirect_to new_group_play_list_list_entry_path(Current.group, @play_list, q: params[:q]),
        alert: "#{title.full_name} #{entry.errors[:title].to_sentence}."
    end
  end

  def reorder
    @play_list.reorder(params.expect(list_entry_ids: []))
    head :no_content
  end

  private
    def set_play_list
      @play_list = Current.group.play_lists.find(params[:play_list_id])
    end
end
