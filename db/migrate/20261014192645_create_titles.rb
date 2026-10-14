class CreateTitles < ActiveRecord::Migration[8.1]
  def change
    create_table :titles do |t|
      t.integer :kind, null: false
      t.string :name, null: false
      t.integer :season

      t.timestamps
    end
  end
end
