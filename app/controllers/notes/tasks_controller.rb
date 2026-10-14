# Ticks a Markdown task from the note's view page. A task is named by the
# source line its checkbox was rendered from (see ApplicationHelper), and the
# request carries the state to set, so repeating it changes nothing.
class Notes::TasksController < ApplicationController
  before_action :set_note

  def update
    if @note.check_task(params.expect(:line).to_i, params[:checked] == "true")
      head :no_content
    else
      # That line isn't a task any more: the page is out of date.
      head :conflict
    end
  end

  private
    def set_note
      folder = Current.user.folders.find(params.expect(:folder_id))
      @note = Current.user.notes.find_by!(id: params.expect(:note_id), folder: folder)
    end
end
