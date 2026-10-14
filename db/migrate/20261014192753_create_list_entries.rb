class CreateListEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :list_entries do |t|
      t.references :play_list, null: false, foreign_key: true
      t.references :title, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.integer :state, null: false, default: 0
      t.datetime :cancelled_at
      t.text :cancel_note

      t.timestamps
    end
    # At most one active (not_started or in_progress) entry per title in a playlist.
    add_index :list_entries, [ :play_list_id, :title_id ], unique: true, where: "state IN (0, 1)",
      name: "index_list_entries_on_one_active_entry_per_title"
  end
end
