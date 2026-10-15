class Viewing < ApplicationRecord
  belongs_to :group
  belongs_to :episode
  belongs_to :list_entry

  validates :date, presence: true
  validate :episode_belongs_to_the_entrys_title, :group_owns_the_entrys_list

  private
    def episode_belongs_to_the_entrys_title
      if episode && list_entry && episode.title_id != list_entry.title_id
        errors.add(:episode, "isn't part of this entry's title")
      end
    end

    def group_owns_the_entrys_list
      if group && list_entry && group.id != list_entry.list.group_id
        errors.add(:group, "doesn't own this entry's list")
      end
    end
end
