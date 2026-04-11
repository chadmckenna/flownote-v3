module FoldersHelper
  def folder_options_for_select(user, selected_id = nil)
    root = user.root_folder
    options = [ [ "/", root.id ] ]
    build_folder_tree(root.subfolders.order(:name), options, 1)
    options_for_select(options, selected_id)
  end

  private
    def build_folder_tree(folders, options, depth)
      folders.each do |folder|
        prefix = "\u00A0\u00A0" * depth
        options << [ "#{prefix}#{folder.name}", folder.id ]
        build_folder_tree(folder.subfolders.order(:name), options, depth + 1)
      end
    end
end
