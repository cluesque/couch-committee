class Groups::Lists::HistoriesController < ApplicationController
  include SetCurrentGroup

  def show
    @list = Current.group.lists.find(params[:list_id])
    @events = @list.history
    @other_lists = other_lists_by_watch(@events.grep(Viewing))
  end

  private
    # For each watch (episode and date), the group's other lists it's also recorded on, which
    # unwatching it will affect too.
    def other_lists_by_watch(viewings)
      Viewing.where(group: Current.group, episode_id: viewings.map(&:episode_id)).includes(list_entry: :list)
        .group_by { |viewing| [ viewing.episode_id, viewing.date ] }
        .transform_values { |same_watch| same_watch.map { |viewing| viewing.list_entry.list }.uniq - [ @list ] }
    end
end
