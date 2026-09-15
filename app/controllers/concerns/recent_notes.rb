module RecentNotes
  extend ActiveSupport::Concern

  LIMIT = 5

  private
    # The notes this browser has opened, newest first. Kept in the session cookie:
    # it's a handful of ids, it's per-browser like the history it mirrors, and it
    # costs no schema and no write on a read request.
    def record_recent_note(note)
      session[:recent_note_ids] = ([ note.id ] + recent_note_ids).uniq.first(LIMIT)
    end

    # Re-read through the user's own notes, so an id left in a stale cookie can
    # only ever name a note they still own. Deleted notes drop out silently.
    def recent_notes
      return Note.none if recent_note_ids.empty?

      by_id = Current.user.notes.includes(:folder).where(id: recent_note_ids).index_by(&:id)
      recent_note_ids.filter_map { |id| by_id[id] }
    end

    def recent_note_ids
      Array(session[:recent_note_ids])
    end
end
