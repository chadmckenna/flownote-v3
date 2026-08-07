module ShellLoader
  extend ActiveSupport::Concern

  private
    def load_shell
      @folder ||= @note&.folder || Current.user.root_folder
      @ancestors = @folder.ancestors
      @subfolders = @folder.subfolders.order(:name)
      # By owner as well as folder, so a stray cross-user note could never surface
      # in someone's sidebar.
      @sidebar_notes = Current.user.notes.where(folder: @folder).order(updated_at: :desc)
      @folder_shell = true
    end
end
