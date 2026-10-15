class RenamePlayListsToLists < ActiveRecord::Migration[8.1]
  def change
    rename_table :play_lists, :lists
    rename_column :list_entries, :play_list_id, :list_id
  end
end
