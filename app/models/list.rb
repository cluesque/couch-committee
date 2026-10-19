class List < ApplicationRecord
  has_many :list_memberships, dependent: :destroy
  has_many :users, through: :list_memberships
  has_many :list_entries
  has_many :viewings, through: :list_entries

  validates :name, presence: true

  # There's no pending-invite state: someone not yet signed up gets a User with just their email,
  # which they claim on first Google sign-in.
  def invite(email)
    transaction do
      list_memberships.create!(user: User.find_or_create_by!(email: email))
    end
  end

  # Returns the new entry, unsaved with errors if the title is already active here.
  def add(title, recommendation: nil)
    list_entries.create(title: title, recommendation: recommendation, sequence: list_entries.maximum(:sequence).to_i + 1)
  end

  # Every viewing on this list, whether or not its entry is finished, plus each cancelled entry,
  # most recent first. A mix of Viewings and ListEntries.
  def history
    events = viewings.includes(:episode, list_entry: :title) + list_entries.cancelled.includes(:title)

    events.sort_by do |event|
      event.is_a?(Viewing) ? [ event.date, event.created_at ] : [ event.cancelled_at.to_date, event.cancelled_at ]
    end.reverse
  end

  # Puts the given active entries in the given order, among the places they already hold, then
  # numbers the whole active list 1, 2, 3…. With the list filtered to movies, say, the movies are
  # reshuffled among their own places while the series between them stay put. Ids that aren't
  # active entries here are ignored, and an entry the client didn't know about keeps its place.
  def reorder(list_entry_ids)
    active = list_entries.active.order(:sequence, :id).to_a
    by_id = active.index_by(&:id)
    moving = list_entry_ids.map(&:to_i).uniq.filter_map { |id| by_id[id] }
    places = active.each_index.select { |index| active[index].in?(moving) }

    arranged = active.dup
    places.zip(moving).each { |place, entry| arranged[place] = entry }

    transaction do
      arranged.each.with_index(1) { |entry, sequence| entry.update!(sequence: sequence) unless entry.sequence == sequence }
    end
  end
end
