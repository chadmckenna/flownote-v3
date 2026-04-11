class AddFolderToNotes < ActiveRecord::Migration[8.1]
  def change
    add_reference :notes, :folder, null: true, foreign_key: true
  end
end
