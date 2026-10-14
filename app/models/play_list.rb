class PlayList < ApplicationRecord
  belongs_to :group
  has_many :list_entries

  validates :name, presence: true

  # Returns the new entry, unsaved with errors if the title is already active here.
  def add(title)
    list_entries.create(title: title, sequence: list_entries.maximum(:sequence).to_i + 1)
  end
end
