class AddSlugToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :slug, :string
    add_index :notes, :slug, unique: true
  end
end
