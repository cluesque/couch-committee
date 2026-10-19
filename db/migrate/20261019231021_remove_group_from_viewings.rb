# A watch now counts only on the list it was recorded on, so a viewing no longer needs its group.
class RemoveGroupFromViewings < ActiveRecord::Migration[8.1]
  def change
    remove_reference :viewings, :group, foreign_key: true, index: true
  end
end
