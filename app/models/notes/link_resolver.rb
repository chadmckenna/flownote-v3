module Notes
  # Resolves the targets of [[wiki links]] to notes. Every lookup goes through
  # the user association, so a link can only ever resolve to a note the reader
  # owns — there is no scope for a caller to forget.
  #
  # Targets read like file paths relative to the linking note's own folder, so
  # the same link means the same thing whether it is typed here or in a synced
  # working copy:
  #
  #   [[Title]]         the note's own folder first, then any folder
  #   [[test/Title]]    the "test" folder below this one, then below the root
  #   [[../Title]]      the parent folder
  #   [[/a/Title]]      absolute — "~/" means the root folder too
  #
  # An unqualified title that matches several notes resolves to the most
  # recently updated, which is why the autocomplete qualifies duplicates. A
  # trailing ".md" is optional, matching the file name the editor shows.
  #
  # Matching is case-insensitive over ASCII only, to line up exactly with
  # SQLite's NOCASE collation — folding in Ruby with String#downcase instead
  # would fold more (accented letters) than the SQL side does, and the two would
  # disagree about what matched.
  class LinkResolver
    MAX_TARGETS = 200

    # from: the note the links were written in. Without it there is nowhere to
    # be relative to, so every path resolves from the root.
    def initialize(user:, from: nil)
      @user = user
      @from = from
    end

    # targets: the raw strings found between [[ and ]].
    # => { "test/Title" => #<Note>, "Nope" => nil }
    def resolve(targets)
      keys = targets.map { |target| target.to_s.strip }.reject(&:blank?).uniq.first(MAX_TARGETS)
      return {} if keys.empty?

      notes = notes_by_title(keys.flat_map { |key| titles_in(key) })
      keys.index_with { |key| pick(key, notes) }
    end

    private
      def pick(key, notes)
        paths = target_paths(key)

        titles_in(key).each do |title|
          candidates = notes[fold(title)] || []
          match = paths.lazy.filter_map { |path| in_folder(candidates, path) }.first
          # An unqualified title that isn't in this folder still finds a note
          # anywhere: the folder is a preference, not a requirement.
          match ||= candidates.last unless key.include?("/")
          return match if match
        end

        nil
      end

      # Ordered ascending, so searching in reverse takes the most recently
      # updated of the notes that match equally well.
      def in_folder(candidates, path)
        candidates.reverse.find { |note| folder_paths[note.folder_id] == path }
      end

      def notes_by_title(titles)
        @user.notes
             .where("title COLLATE NOCASE IN (?)", titles.uniq)
             .order(:updated_at, :id)
             .select(:id, :title, :folder_id)
             .group_by { |note| fold(note.title) }
      end

      # "Work/Title.md" => ["Title.md", "Title"] — a title that really ends in
      # ".md" wins over the same title without it. A title containing a slash is
      # only reachable unqualified, which the autocomplete handles by inserting
      # the qualified form only when it has to.
      def titles_in(key)
        title = key.split("/").last.to_s.strip
        [ title, title.sub(/\.md\z/i, "") ].uniq.reject(&:blank?)
      end

      # The folder paths to try, in order. A relative path falls back to the
      # same path read from the root, so links written before paths were
      # relative keep working; a path that climbs past the root matches nothing.
      def target_paths(key)
        dirs = key.split("/")[0..-2].to_a.map(&:strip)
        return [ base_path ].compact if dirs.empty?

        if dirs.first.blank? || dirs.first == "~"
          [ descend("", dirs.drop(1)) ].compact
        else
          [ base_path && descend(base_path, dirs), descend("", dirs) ].compact.uniq
        end
      end

      # "work" + ["..", "test"] => "test". nil once ".." runs out of root.
      def descend(path, dirs)
        segments = path.split("/")

        dirs.each do |dir|
          next if dir.blank? || dir == "."

          if dir == ".."
            return nil if segments.empty?
            segments.pop
          else
            segments << dir
          end
        end

        fold(segments.join("/"))
      end

      def base_path
        @base_path ||= @from && folder_paths[@from.folder_id]
      end

      def folder_paths
        @folder_paths ||= Folder.path_map(@user).transform_values { |path| fold(path) }
      end

      def fold(string)
        string.to_s.strip.tr("A-Z", "a-z")
      end
  end
end
