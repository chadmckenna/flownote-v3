class FoldNoteTitlesAndFolderNamesCaseInsensitively < ActiveRecord::Migration[8.1]
  # Both names are unique per parent, but only byte for byte, while every link
  # target is matched case-insensitively — so "Work" and "work" could sit side by
  # side in one folder and a [[Work/Note]] link had two places to mean. NOCASE
  # makes the uniqueness indexes fold the same way the lookups always have.
  def up
    deduplicate("notes", "title", %w[ folder_id ])
    deduplicate("folders", "name", %w[ user_id parent_id ])

    change_column :notes, :title, :string, collation: "NOCASE"
    change_column :folders, :name, :string, null: false, collation: "NOCASE"
  end

  def down
    change_column :notes, :title, :string
    change_column :folders, :name, :string, null: false
  end

  private
    # Names that differ only in case collide once the index folds them, so the
    # oldest keeps its name and the rest are suffixed the way a file manager
    # renames a clashing file — "Name (1)", "Name (2)" — skipping every name
    # already in use among its siblings. NULLs are left alone: SQLite counts
    # those as distinct, and there is no name there to derive a new one from.
    def deduplicate(table, column, scope_columns)
      scope = scope_columns.join(", ")
      rows = select_all("SELECT id, #{scope}, #{column} FROM #{table} ORDER BY #{scope}, id").to_a

      rows.group_by { |row| row.values_at(*scope_columns) }.each_value do |siblings|
        taken = siblings.filter_map { |row| fold(row[column]) }.to_set
        seen = Set.new

        siblings.each do |row|
          name = row[column]
          next if name.nil?

          if seen.include?(fold(name))
            name = unused_name(name, taken)
            taken << fold(name)
            execute("UPDATE #{table} SET #{column} = #{quote(name)} WHERE id = #{row["id"].to_i}")
          end

          seen << fold(name)
        end
      end
    end

    def unused_name(name, taken)
      (1..).lazy.map { |n| "#{name} (#{n})" }.find { |candidate| taken.exclude?(fold(candidate)) }
    end

    # ASCII only, exactly what SQLite's NOCASE folds — String#downcase would fold
    # accented letters too and disagree with the index about what collides.
    def fold(string)
      string&.tr("A-Z", "a-z")
    end
end
