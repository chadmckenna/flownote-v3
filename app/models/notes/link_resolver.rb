module Notes
  # Resolves the targets of [[wiki links]] to notes. Every lookup goes through
  # the user association, so a link can only ever resolve to a note the reader
  # owns — there is no scope for a caller to forget.
  #
  # "[[Title]]" matches any note with that title; titles aren't unique, so the
  # most recently updated one wins. "[[Work/Title]]" matches only inside that
  # folder path, which is how two notes sharing a title are told apart. Paths are
  # relative to the user's root folder; a leading "~/" or "/" is ignored.
  #
  # Matching is case-insensitive over ASCII only, to line up exactly with
  # SQLite's NOCASE collation — folding in Ruby with String#downcase instead
  # would fold more (accented letters) than the SQL side does, and the two would
  # disagree about what matched.
  class LinkResolver
    MAX_TARGETS = 200

    def initialize(user:)
      @user = user
    end

    # targets: the raw strings found between [[ and ]].
    # => { "Work/Title" => #<Note>, "Nope" => nil }
    def resolve(targets)
      keys = targets.map { |target| target.to_s.strip }.reject(&:blank?).uniq.first(MAX_TARGETS)
      return {} if keys.empty?

      notes = notes_by_title(keys.map { |key| title_in(key) })
      keys.index_with { |key| pick(key, notes) }
    end

    private
      def pick(key, notes)
        candidates = notes[fold(title_in(key))] || []
        path = folder_path_in(key)

        if path
          candidates.reverse.find { |note| folder_paths[note.folder_id] == path }
        else
          # Ordered ascending, so the last candidate is the most recently updated.
          candidates.last
        end
      end

      def notes_by_title(titles)
        @user.notes
             .where("title COLLATE NOCASE IN (?)", titles.uniq)
             .order(:updated_at, :id)
             .select(:id, :title, :folder_id)
             .group_by { |note| fold(note.title) }
      end

      # "Work/Projects/Title" => "Title". A title containing a slash is only
      # reachable unqualified, which the autocomplete handles by inserting the
      # qualified form only when it has to.
      def title_in(key)
        key.split("/").last.to_s.strip
      end

      # "Work/Projects/Title" => "work/projects", "~/Title" => "" (the root
      # folder), "Title" => nil (unqualified — any folder matches).
      def folder_path_in(key)
        return nil unless key.include?("/")

        fold(key.split("/")[0..-2].join("/").sub(/\A[~\/]+/, ""))
      end

      def folder_paths
        @folder_paths ||= Folder.path_map(@user).transform_values { |path| fold(path) }
      end

      def fold(string)
        string.to_s.strip.tr("A-Z", "a-z")
      end
  end
end
