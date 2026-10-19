# People now belong to lists directly. Everyone in a group becomes a member of each of its lists,
# then groups go.
class ReplaceGroupsWithListMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :list_memberships do |t|
      t.references :list, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :list_memberships, [ :list_id, :user_id ], unique: true

    execute <<~SQL
      INSERT INTO list_memberships (list_id, user_id, created_at, updated_at)
      SELECT lists.id, group_memberships.user_id, group_memberships.created_at, group_memberships.created_at
      FROM lists JOIN group_memberships ON group_memberships.group_id = lists.group_id
    SQL

    remove_reference :lists, :group, foreign_key: true, index: true
    drop_table :group_memberships
    drop_table :groups
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
