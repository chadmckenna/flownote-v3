module NotesHelper
  # The editor's [[ ]] autocomplete list, embedded in the page rather than
  # fetched: it's titles and folder names only, ~40 bytes a note, and it saves
  # introducing a JSON endpoint and a fetch for a dropdown. Capped at the notes
  # you've touched most recently — past the cap a title still resolves when typed
  # by hand, it just isn't offered.
  #
  # You filter by typing the title; what gets inserted is the absolute path.
  COMPLETION_LIMIT = 500

  def note_link_completions
    paths = Folder.path_map(Current.user)

    Current.user.notes.order(updated_at: :desc).limit(COMPLETION_LIMIT)
           .select(:id, :title, :folder_id, :updated_at).map do |note|
      path = folder_path_label(paths[note.folder_id])

      {
        label: note.title,
        # Same label as a search result's, so the two lists read alike.
        detail: path,
        # Always the absolute path, never the bare title: a title only names one
        # note within its own folder, so "~/Work/Title" is the spelling that
        # means the note you picked from wherever the link is written.
        apply: "#{path}/#{note.title}"
      }
    end
  end
end
