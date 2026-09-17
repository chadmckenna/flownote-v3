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
    # Only NULL titles are skipped — SQLite counts those as distinct, so they
    # never collide. An empty string is a value like any other and does collide,
    # so it is suffixed too, degenerate as " (1)" looks.
    def deduplicate_titles
      rows = select_all("SELECT id, folder_id, title FROM notes ORDER BY folder_id, id").to_a

      rows.group_by { |row| row["folder_id"] }.each_value do |folder_rows|
        taken = folder_rows.filter_map { |row| row["title"] }.to_set
        seen = Set.new

        folder_rows.each do |row|
          title = row["title"]
          next if title.nil?

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
