# Records that an entry's episode was watched on a date. The entry moves to in_progress, or to
# watched once every episode of its title has a Viewing on it. Other lists with the same title are
# untouched: each list keeps its own record.
class WatchRecorder
  def self.call(...)
    new(...).call
  end

  def initialize(entry, episode:, date:)
    @entry, @episode, @date = entry, episode, date
  end

  # Returns the new Viewing.
  def call
    ListEntry.transaction do
      @entry.viewings.create!(episode: @episode, date: @date).tap do
        @entry.update!(state: @entry.state_from_viewings)
      end
    end
  end
end
