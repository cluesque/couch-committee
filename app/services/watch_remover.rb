# Undoes a recorded watch. Recording put a Viewing on every list in the group that had the title, so
# this removes all of them (the same episode, watched on the same date), then puts each affected
# entry back in the state its remaining viewings call for.
class WatchRemover
  class Refused < StandardError; end

  def self.call(viewing)
    new(viewing).call
  end

  # The viewing and its counterparts on the group's other lists.
  def self.same_watch(viewing)
    Viewing.where(group_id: viewing.group_id, episode_id: viewing.episode_id, date: viewing.date)
  end

  def initialize(viewing)
    @viewing = viewing
  end

  # Returns the viewings removed. Raises Refused, removing nothing, if a finished watch-through
  # would reopen while a rewatch of the same title is already active on its list.
  def call
    viewings = self.class.same_watch(@viewing).includes(list_entry: [ :list, :title ]).to_a

    ListEntry.transaction do
      viewings.each(&:destroy!)
      viewings.map(&:list_entry).uniq.each { |entry| reopen(entry) }
    end

    viewings
  end

  private
    def reopen(entry)
      entry.viewings.reset
      state = entry.state_from_viewings

      if entry.watched? && state != "watched" && entry.list.list_entries.active.exists?(title_id: entry.title_id)
        raise Refused, "#{entry.title.full_name} is already back on #{entry.list.name} for a rewatch, " \
          "so this earlier watch-through can't be reopened."
      end

      entry.update!(state: state)
    end
end
