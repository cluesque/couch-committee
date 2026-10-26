# Tags a list's people make up for its entries ("Alice+"), each with a color. A tag belongs to one
# list; an entry can have several.
class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :list, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end
    add_index :tags, [ :list_id, :name ], unique: true

    create_table :list_entry_tags do |t|
      t.references :list_entry, null: false, foreign_key: true, index: false
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :list_entry_tags, [ :list_entry_id, :tag_id ], unique: true
  end
end
