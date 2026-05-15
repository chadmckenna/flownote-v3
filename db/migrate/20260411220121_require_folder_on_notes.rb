class RequireFolderOnNotes < ActiveRecord::Migration[8.1]
  def up
    # Create root folders for existing users, reparent their folders, and assign unfiled notes
    execute <<~SQL
      INSERT INTO folders (name, user_id, parent_id, created_at, updated_at)
      SELECT '/', id, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      WHERE id NOT IN (SELECT DISTINCT user_id FROM folders WHERE parent_id IS NULL AND name = '/')
    SQL

    # Reparent existing root-level folders under the new root
    execute <<~SQL
      UPDATE folders
      SET parent_id = (
        SELECT rf.id FROM folders rf
        WHERE rf.user_id = folders.user_id AND rf.parent_id IS NULL AND rf.name = '/'
      )
      WHERE parent_id IS NULL AND name != '/'
    SQL

    # Assign unfiled notes to the user's root folder
    execute <<~SQL
      UPDATE notes
      SET folder_id = (
        SELECT rf.id FROM folders rf
        WHERE rf.user_id = notes.user_id AND rf.parent_id IS NULL AND rf.name = '/'
      )
      WHERE folder_id IS NULL
    SQL

    change_column_null :notes, :folder_id, false
  end

  def down
    change_column_null :notes, :folder_id, true
  end
end
