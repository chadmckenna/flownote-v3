module NotesHelper
  # The editor's [[ ]] autocomplete list, embedded in the page rather than
  # fetched: it's titles and folder names only, ~40 bytes a note, and it saves
  # introducing a JSON endpoint and a fetch for a dropdown. Capped at the notes
  # you've touched most recently — past the cap a title still resolves when typed
  # by hand, it just isn't offered.
  COMPLETION_LIMIT = 500

  def note_link_completions
    paths = Folder.path_map(Current.user)
    notes = Current.user.notes.order(updated_at: :desc).limit(COMPLETION_LIMIT)
                       .select(:id, :title, :folder_id, :updated_at)
    duplicated = notes.map(&:title).tally.select { |_title, count| count > 1 }

    notes.map do |note|
      path = paths[note.folder_id]
      {
        label: note.title,
        # Same label as a search result's, so the two lists read alike.
        detail: folder_path_label(path),
        # A title shared with another note only resolves to the one you picked
        # when it's qualified with its folder path.
        apply: duplicated[note.title] ? "#{path.presence || "~"}/#{note.title}" : note.title
      }
    end
  end
end
