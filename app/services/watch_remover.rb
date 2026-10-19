# Undoes a recorded watch: removes the Viewing, then puts its entry back in the state its remaining
# viewings call for.
class WatchRemover
  class Refused < StandardError; end

  def self.call(viewing)
    new(viewing).call
  end

  def initialize(viewing)
    @viewing = viewing
  end

  # Raises Refused, removing nothing, if a finished watch-through would reopen while a rewatch of
  # the same title is already active on its list.
  def call
    ListEntry.transaction do
      @viewing.destroy!
      reopen(@viewing.list_entry.reload)
    end
  end

  private
    def reopen(entry)
      state = entry.state_from_viewings

      if entry.watched? && state != "watched" && entry.list.list_entries.active.exists?(title_id: entry.title_id)
        raise Refused, "#{entry.title.full_name} is already back on #{entry.list.name} for a rewatch, " \
          "so this earlier watch-through can't be reopened."
      end

      entry.update!(state: state)
    end
end
