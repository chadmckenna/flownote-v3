module Notes
  # Plain keyword search over a user's notes: case-insensitive LIKE on title and
  # body, scoped through the association so it can only ever see the user's own
  # notes. Deliberately simple — no FTS, no ranking. The query object is the seam
  # to swap in a smarter backend later without touching the controller or views.
  #
  # The query is split into tokens on whitespace and underscores, and every token
  # must appear in the title or body. This makes "sourdough bread" and
  # "sourdough_bread" find the same note — underscores in filenames/titles read
  # as word separators rather than literal characters.
  class Search
    LIMIT = 10

    def initialize(user:, query:)
      @user = user
      @query = query.to_s.strip
    end

    def results
      return Note.none if tokens.empty?

      tokens.reduce(base_scope) do |scope, token|
        term = "%#{Note.sanitize_sql_like(token)}%"
        # ESCAPE is required: sanitize_sql_like escapes with "\", but SQLite's
        # LIKE has no default escape character, so without this the escaped "_"
        # and "%" would still be treated as wildcards.
        scope.where("title LIKE :t ESCAPE '\\' OR body LIKE :t ESCAPE '\\'", t: term)
      end
    end

    private

    def tokens
      @tokens ||= @query.split(/[\s_]+/).reject(&:blank?)
    end

    def base_scope
      @user.notes
           .includes(:folder)
           .order(updated_at: :desc)
           .limit(LIMIT)
    end
  end
end
