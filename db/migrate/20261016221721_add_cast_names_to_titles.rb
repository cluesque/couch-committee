class AddCastNamesToTitles < ActiveRecord::Migration[8.1]
  def change
    add_column :titles, :cast_names, :string
  end
end
