module ShellLoader
  extend ActiveSupport::Concern

  private
    def load_shell
      @folder ||= @note&.folder || Current.user.root_folder
      @ancestors = @folder.ancestors
      @subfolders = @folder.subfolders.order(:name)
      @sidebar_notes = @folder.notes.order(updated_at: :desc)
      @folder_shell = true
    end
end
