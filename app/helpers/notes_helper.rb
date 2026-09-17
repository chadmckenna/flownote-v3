module NotesHelper
  # The editor's [[ ]] autocomplete list, embedded in the page rather than
  # fetched: it's names and paths only, ~40 bytes an entry, and it saves
  # introducing a JSON endpoint and a fetch for a dropdown. Notes are capped at
  # the ones you've touched most recently — past the cap a title still resolves
  # when typed by hand, it just isn't offered.
  #
  # You filter by typing the name; what gets inserted is the absolute path.
  COMPLETION_LIMIT = 500

  def note_link_completions
    paths = Folder.path_map(Current.user)

    note_completions(paths) + folder_completions(paths)
  end

  private
    def note_completions(paths)
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

    # Folders are offered too, since [[~/Work/]] links to the folder's own page.
    # The trailing slash is what asks for the folder rather than a note of the
    # same name, so it shows in the label as well as in what gets inserted. Every
    # folder is listed: they are already loaded for the paths above, and there are
    # far fewer of them than notes.
    def folder_completions(paths)
      paths.values.sort.map do |path|
        {
          label: path.present? ? "#{path.split("/").last}/" : "~/",
          detail: parent_path_label(path),
          apply: "#{folder_path_label(path)}/"
        }
      end
    end

    # Where the folder itself lives, the way a note's detail is where it lives.
    # The root has no parent to name, so it answers with nothing.
    def parent_path_label(path)
      return "" if path.blank?

      folder_path_label(path.split("/")[0..-2].join("/"))
    end
end
