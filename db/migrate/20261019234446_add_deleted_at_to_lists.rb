# Deleting a list only hides it, so it can be brought back (Undo, or a console).
class AddDeletedAtToLists < ActiveRecord::Migration[8.1]
  def change
    add_column :lists, :deleted_at, :datetime
  end
end
