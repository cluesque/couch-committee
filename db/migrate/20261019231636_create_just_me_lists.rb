# Everyone gets a "Just Me" list on first sign-in (see User#create_just_me_list). This gives one to
# everyone who has already signed in. Someone invited who hasn't signed in yet gets theirs when
# they do.
class CreateJustMeLists < ActiveRecord::Migration[8.1]
  def up
    select_values("SELECT id FROM users WHERE google_id IS NOT NULL").each do |user_id|
      now = connection.quote(Time.current)
      list_id = insert("INSERT INTO lists (name, created_at, updated_at) VALUES ('Just Me', #{now}, #{now})")
      execute "INSERT INTO list_memberships (list_id, user_id, created_at, updated_at) " \
        "VALUES (#{list_id}, #{Integer(user_id)}, #{now}, #{now})"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
