class AddBodyToNotes < ActiveRecord::Migration[8.1]
  def up
    add_column :notes, :body, :text
    execute "DELETE FROM action_text_rich_texts WHERE record_type = 'Note'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
