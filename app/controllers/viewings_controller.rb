# Recently watched: the latest watches across every list I'm on, newest first. One watch recorded
# on several lists (as every watch was, before Phase 17) is one row, naming each list.
class ViewingsController < ApplicationController
  LIMIT = 50

  def index
    viewings = Viewing.joins(:list_entry).where(list_entries: { list_id: Current.user.lists.select(:id) })
      .includes(:episode, list_entry: [ :title, :list ]).order(date: :desc, created_at: :desc).limit(LIMIT)
    @watches = viewings.group_by { |viewing| [ viewing.episode_id, viewing.date ] }.values
  end
end
