module FoldersHelper
  def folder_or_root_path(folder)
    folder&.root? ? root_path : folder_path(folder)
  end

  def folder_path_string(folder)
    return "~" if folder.root?
    parts = folder.ancestors.reject(&:root?).map(&:name) + [ folder.name ]
    "~/#{parts.join('/')}"
  end
end
