class Notes::PublicationsController < ApplicationController
  before_action :set_note

  def create
    if Current.user.username.blank?
      # Not redirect_back_or_to: the button always sends a referer, which would
      # bounce the user back to the note instead of the profile they need.
      redirect_to profile_path, alert: "Set a username on your profile before sharing notes."
    else
      @note.publish!
      redirect_back_or_to note_path, notice: "Note published."
    end
  end

  def destroy
    @note.unpublish!
    redirect_back_or_to note_path, notice: "Note unpublished."
  end

  private
    def set_note
      @note = Current.user.folders.find(params.expect(:folder_id)).notes.find(params.expect(:note_id))
    end

    def note_path
      folder_note_path(@note.folder, @note)
    end
end
