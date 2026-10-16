class AddRecommendationToListEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :list_entries, :recommendation, :string
  end
end
