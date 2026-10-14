class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :display_name
      t.string :google_id

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :google_id, unique: true
  end
end
