class List < ApplicationRecord
  belongs_to :group
  has_many :list_entries
  has_many :viewings, through: :list_entries

  validates :name, presence: true

  # Returns the new entry, unsaved with errors if the title is already active here.
  def add(title)
    list_entries.create(title: title, sequence: list_entries.maximum(:sequence).to_i + 1)
  end

  # Every viewing on this list, whether or not its entry is finished, plus each cancelled entry,
  # most recent first. A mix of Viewings and ListEntries.
  def history
    events = viewings.includes(:episode, list_entry: :title) + list_entries.cancelled.includes(:title)

    events.sort_by do |event|
      event.is_a?(Viewing) ? [ event.date, event.created_at ] : [ event.cancelled_at.to_date, event.cancelled_at ]
    end.reverse
  end

  # Puts the given active entries first, in the given order. Ids that aren't active entries here are
  # ignored. An entry added since the client loaded the list is left at the end, where it already is.
  def reorder(list_entry_ids)
    entries = list_entries.active.where(id: list_entry_ids).index_by(&:id)
    ordered = list_entry_ids.map(&:to_i).uniq.filter_map { |id| entries[id] }

    transaction do
      ordered.each.with_index(1) { |entry, sequence| entry.update!(sequence: sequence) }
    end
  end
end
