module FoldersHelper
  def folder_or_root_path(folder)
    folder&.root? ? root_path : folder_path(folder)
  end

  # "~" for the root folder, "~/Work/Projects" below it. The user's folders are
  # loaded once per request, so a list of notes can label every row without a
  # query (or an ancestor walk) each.
  def folder_path_string(folder)
    path = folder_paths[folder.id]
    path.present? ? "~/#{path}" : "~"
  end

  private
    def folder_paths
      @folder_paths ||= Folder.path_map(Current.user)
    end
end
