module Notes
  # Resolves the targets of [[wiki links]] to notes and folders. Every lookup
  # goes through the user association, so a link can only ever resolve to
  # something the reader owns — there is no scope for a caller to forget.
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
  # A target that names no note resolves to a folder of that path instead, and a
  # trailing slash asks for one outright: [[test/]], [[../]], [[~/]]. A note wins
  # over a folder of the same name in the same place, the way the nearer match
  # always does.
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
    # => { "test/Title" => #<Note>, "test/" => #<Folder>, "Nope" => nil }
    def resolve(targets)
      keys = targets.map { |target| target.to_s.strip }.reject(&:blank?).uniq.first(MAX_TARGETS)
      return {} if keys.empty?

      notes = notes_by_title(keys.flat_map { |key| key_titles(key) })
      keys.index_with { |key| pick(key, notes) }
    end

    private
      def pick(key, notes)
        rooted, segments = split_path(key)
        candidate_paths = paths_for(rooted, segments)
        return folder_at(candidate_paths) if key.end_with?("/")

        titles = titles_in(segments.last)

        note_at(titles, paths_for(rooted, segments[0..-2]), notes) ||
          folder_at(candidate_paths) ||
          # An unqualified title that is nowhere nearby still finds a note in any
          # folder: the folder is a preference, not a requirement.
          (note_anywhere(titles, notes) if !rooted && segments.one?)
      end

      # Paths outside, titles inside: proximity decides first, so the nearer
      # folder wins even when a further one holds the exact ".md" spelling.
      def note_at(titles, paths, notes)
        paths.each do |path|
          titles.each do |title|
            match = in_folder(notes[fold(title)] || [], path)
            return match if match
          end
        end

        nil
      end

      def note_anywhere(titles, notes)
        titles.filter_map { |title| notes[fold(title)]&.last }.first
      end

      # Ordered ascending, so searching in reverse takes the most recently
      # updated of the notes that match equally well.
      def in_folder(candidates, path)
        candidates.reverse.find { |note| folder_paths[note.folder_id] == path }
      end

      def folder_at(paths)
        paths.filter_map { |path| folders_by_path[path] }.first
      end

      def notes_by_title(titles)
        return {} if titles.empty?

        @user.notes
             .where("title COLLATE NOCASE IN (?)", titles.uniq)
             .order(:updated_at, :id)
             .select(:id, :title, :folder_id)
             .group_by { |note| fold(note.title) }
      end

      def key_titles(key)
        key.end_with?("/") ? [] : titles_in(split_path(key).last.last)
      end

      # "Title.md" => ["Title.md", "Title"] — a title that really ends in ".md"
      # wins over the same title without it. A title containing a slash is only
      # reachable unqualified, which the autocomplete handles by inserting the
      # qualified form only when it has to.
      def titles_in(title)
        title = title.to_s.strip
        [ title, title.sub(/\.md\z/i, "") ].uniq.reject(&:blank?)
      end

      # "~/a/b" => [true, ["a", "b"]]; "../b" => [false, ["..", "b"]]. A leading
      # "/" splits to a blank first segment, and "/" alone to nothing at all —
      # both name the root.
      def split_path(key)
        @split_paths ||= {}
        @split_paths[key] ||= begin
          segments = key.split("/").map(&:strip)
          rooted = segments.first.blank? || segments.first == "~"

          [ rooted, rooted ? segments.drop(1) : segments ]
        end
      end

      # The folder paths to try, in order. A relative path falls back to the same
      # path read from the root, so links written before paths were relative keep
      # working; a path that climbs past the root matches nothing.
      def paths_for(rooted, dirs)
        return [ descend("", dirs) ].compact if rooted
        return [ base_path ] if dirs.empty?

        [ descend(base_path, dirs), descend("", dirs) ].compact.uniq
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

      # The folder a relative target is read from. With no linking note there is
      # nowhere to be relative to, so the root stands in for it.
      def base_path
        @base_path ||= (@from && folder_paths[@from.folder_id]) || ""
      end

      # Loaded once: the note lookup needs each note's folder path, and a link to
      # a folder needs the folder itself.
      def folders_by_id
        @folders_by_id ||= @user.folders.index_by(&:id)
      end

      def folder_paths
        @folder_paths ||= folders_by_id.transform_values { |folder| fold(Folder.path_for(folder, folders_by_id)) }
      end

      # A folder path is unique among the user's folders, so nothing is lost here.
      def folders_by_path
        @folders_by_path ||= folders_by_id.values.index_by { |folder| folder_paths[folder.id] }
      end

      def fold(string)
        string.to_s.strip.tr("A-Z", "a-z")
      end
  end
end
