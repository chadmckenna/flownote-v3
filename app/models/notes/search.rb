module Notes
  # Plain keyword search over a user's notes: case-insensitive LIKE on title and
  # body, scoped through the association so it can only ever see the user's own
  # notes. Deliberately simple — no FTS, no ranking. The query object is the seam
  # to swap in a smarter backend later without touching the controller or views.
  class Search
    LIMIT = 20

    def initialize(user:, query:)
      @user = user
      @query = query.to_s.strip
    end

    def results
      return Note.none if @query.blank?

      term = "%#{Note.sanitize_sql_like(@query)}%"
      @user.notes
           .includes(:folder)
           .where("title LIKE :t OR body LIKE :t", t: term)
           .order(updated_at: :desc)
           .limit(LIMIT)
    end
  end
end
