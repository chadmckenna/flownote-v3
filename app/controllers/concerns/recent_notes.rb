module RecentNotes
  extend ActiveSupport::Concern

  LIMIT = 5

  private
    # The notes this browser has opened, newest first. Kept in the session cookie:
    # it's a handful of ids, it's per-browser like the history it mirrors, and it
    # costs no schema and no write on a read request.
    def record_recent_note(note)
      return if prefetch_request?

      session[:recent_note_ids] = ([ note.id ] + recent_note_ids).uniq.first(LIMIT)
    end

    # Re-read through the user's own notes, so an id left in a stale cookie can
    # only ever name a note they still own. Ids that no longer resolve — a deleted
    # note, or another account's on a shared browser — are dropped from the cookie
    # rather than holding a slot until five fresh visits push them off the end.
    def recent_notes(except: nil)
      return Note.none if recent_note_ids.empty?

      by_id = Current.user.notes.includes(:folder).where(id: recent_note_ids).index_by(&:id)
      session[:recent_note_ids] = recent_note_ids.select { |id| by_id.key?(id) }

      recent_note_ids.filter_map { |id| by_id[id] unless id == except }
    end

    def recent_note_ids
      Array(session[:recent_note_ids])
    end

    # Turbo prefetches a link on hover, and it's opt-out — without this, "recent"
    # would drift into "the last five things under the mouse". The prefetch is a
    # real GET of the page, just a speculative one.
    def prefetch_request?
      request.headers["X-Sec-Purpose"].to_s.include?("prefetch") ||
        request.headers["Sec-Purpose"].to_s.include?("prefetch")
    end
end
