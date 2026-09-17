class EnforceUniqueNoteTitlesPerFolder < ActiveRecord::Migration[8.1]
  def up
    deduplicate_titles
    add_index :notes, [ :folder_id, :title ], unique: true
  end

  def down
    remove_index :notes, [ :folder_id, :title ]
  end

  private
    # Two notes in a folder could share a title until now. The oldest keeps it
    # and the rest are suffixed the way a file manager renames a clashing file —
    # "Title (1)", "Title (2)" — skipping every name already in use in that
    # folder, so a note legitimately called "Doc (1)" is left where it is.
    # Blank titles are skipped: SQLite counts NULLs as distinct, so they don't
    # collide, and there is no name here to derive a new one from.
    def deduplicate_titles
      rows = select_all("SELECT id, folder_id, title FROM notes ORDER BY folder_id, id").to_a

      rows.group_by { |row| row["folder_id"] }.each_value do |folder_rows|
        taken = folder_rows.filter_map { |row| row["title"].presence }.to_set
        seen = Set.new

        folder_rows.each do |row|
          title = row["title"]
          next if title.blank?

          if seen.include?(title)
            title = unused_title(title, taken)
            taken << title
            execute("UPDATE notes SET title = #{quote(title)} WHERE id = #{row["id"].to_i}")
          end

          seen << title
        end
      end
    end

    def unused_title(title, taken)
      (1..).lazy.map { |n| "#{title} (#{n})" }.find { |candidate| taken.exclude?(candidate) }
    end
end
