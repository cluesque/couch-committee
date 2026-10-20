# When someone saw the one-time welcome page. People already using the app count as welcomed (they
# can still open it from the account menu); someone invited who hasn't signed in yet sees it.
class AddWelcomedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :welcomed_at, :datetime
    execute "UPDATE users SET welcomed_at = CURRENT_TIMESTAMP WHERE google_id IS NOT NULL"
  end

  def down
    remove_column :users, :welcomed_at
  end
end
