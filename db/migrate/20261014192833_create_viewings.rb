class CreateViewings < ActiveRecord::Migration[8.1]
  def change
    create_table :viewings do |t|
      t.references :group, null: false, foreign_key: true
      t.references :episode, null: false, foreign_key: true
      t.references :list_entry, null: false, foreign_key: true
      t.date :date, null: false

      t.timestamps
    end
  end
end
