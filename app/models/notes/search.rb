module Notes
  # Plain keyword search over a user's notes: case-insensitive LIKE on title and
  # body, plus the note's folder path, scoped through the association so it can
  # only ever see the user's own notes. Deliberately simple — no FTS, no ranking.
  # The query object is the seam to swap in a smarter backend later without
  # touching the controller or views.
  #
  # The query is split into tokens on whitespace and underscores, and every token
  # must appear in the title, the body, or the folder path. This makes "sourdough
  # bread" and "sourdough_bread" find the same note — underscores in
  # filenames/titles read as word separators rather than literal characters — and
  # lets "work sourdough" narrow to the copy filed under Work.
  class Search
    LIMIT = 10

    def initialize(user:, query:)
      @user = user
      @query = query.to_s.strip
    end

    # Notes containing every token come first. A folder-path match pulls in notes
    # that don't contain the word at all — with only LIMIT rows to give away,
    # those would otherwise push out a note that genuinely matches. The folder
    # pass then fills whatever slots are left, so "recipes" still lists the
    # Recipes folder once the real matches have had theirs.
    def results
      return [] if tokens.empty?

      matches = matching(folders: false).to_a
      return matches.first(LIMIT) if matches.size >= LIMIT

      (matches + matching.where.not(id: matches).to_a).first(LIMIT)
    end

    private

    def matching(folders: true)
      tokens.reduce(base_scope) do |scope, token|
        term = "%#{Note.sanitize_sql_like(token)}%"
        folder_ids = folders ? folder_ids_matching(token) : []

        # ESCAPE is required: sanitize_sql_like escapes with "\", but SQLite's
        # LIKE has no default escape character, so without this the escaped "_"
        # and "%" would still be treated as wildcards. An empty folder list binds
        # as IN (NULL), which matches nothing.
        scope.where("title LIKE :t ESCAPE '\\' OR body LIKE :t ESCAPE '\\' OR folder_id IN (:f)",
                    t: term, f: folder_ids)
      end
    end

    def tokens
      @tokens ||= @query.split(/[\s_]+/).reject(&:blank?)
    end

    # Folder paths aren't a column, so they're matched in Ruby against the paths
    # built once from the user's folders. A token matching a folder matches its
    # subfolders too, since it matches anywhere in the path: "work" finds notes
    # in Work/Projects as well as Work.
    def folder_ids_matching(token)
      needle = token.downcase
      folder_paths.select { |_id, path| path.downcase.include?(needle) }.keys
    end

    def folder_paths
      @folder_paths ||= Folder.path_map(@user)
    end

    def base_scope
      @user.notes
           .includes(:folder)
           .order(updated_at: :desc)
           .limit(LIMIT)
    end
  end
end
