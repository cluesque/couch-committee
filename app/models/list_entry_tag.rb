class ListEntryTag < ApplicationRecord
  belongs_to :list_entry
  belongs_to :tag

  validates :tag, uniqueness: { scope: :list_entry }
  validate :tag_belongs_to_the_entrys_list

  private
    def tag_belongs_to_the_entrys_list
      if tag && list_entry && tag.list_id != list_entry.list_id
        errors.add(:tag, "isn't one of this list's tags")
      end
    end
end
