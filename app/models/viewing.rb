class Viewing < ApplicationRecord
  belongs_to :episode
  belongs_to :list_entry

  validates :date, presence: true
  validate :episode_belongs_to_the_entrys_title

  private
    def episode_belongs_to_the_entrys_title
      if episode && list_entry && episode.title_id != list_entry.title_id
        errors.add(:episode, "isn't part of this entry's title")
      end
    end
end
