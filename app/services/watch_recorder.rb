# Records that a group watched an episode on a date. The watch counts toward every active entry for
# that episode's title across all of the group's lists: each gets its own Viewing, then moves to
# in_progress, or to watched once every episode of the title has a Viewing on that entry.
class WatchRecorder
  def self.call(...)
    new(...).call
  end

  def initialize(group:, episode:, date:)
    @group, @episode, @date = group, episode, date
  end

  # Returns the entries the watch was recorded against.
  def call
    entries = ListEntry.active.where(title_id: @episode.title_id, list: @group.lists).to_a

    ListEntry.transaction do
      entries.each do |entry|
        entry.viewings.create!(group: @group, episode: @episode, date: @date)
        entry.update!(state: entry.remaining_episodes.empty? ? :watched : :in_progress)
      end
    end

    entries
  end
end
