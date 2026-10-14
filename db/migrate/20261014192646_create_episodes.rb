class CreateEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :episodes do |t|
      t.references :title, null: false, foreign_key: true, index: false
      t.string :name
      t.integer :number, null: false
      t.date :available_on

      t.timestamps
    end
    add_index :episodes, [ :title_id, :number ], unique: true
  end
end
