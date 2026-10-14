# Renaming a note happens in the sidebar, not the editor: edit swaps the note's
# row for this form (r, or tapping the open note's row), and update puts you
# back on the page you were on.
class Notes::TitlesController < ApplicationController
  before_action :set_note

  def edit
  end

  # The form posts to _top like the folder forms, so a rejected title comes back
  # as a flash on the same page rather than re-rendering into the row.
  def update
    if @note.update(params.expect(note: [ :title ]))
      flash[:notice] = "Note renamed."
    else
      flash[:alert] = @note.errors.full_messages.to_sentence
    end

    redirect_back_or_to edit_folder_note_path(@note.folder, @note)
  end

  private
    def set_note
      folder = Current.user.folders.find(params.expect(:folder_id))
      @note = Current.user.notes.find_by!(id: params.expect(:note_id), folder: folder)
    end
end
