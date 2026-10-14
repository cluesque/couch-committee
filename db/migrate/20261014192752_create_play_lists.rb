class CreatePlayLists < ActiveRecord::Migration[8.1]
  def change
    create_table :play_lists do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
  end
end
