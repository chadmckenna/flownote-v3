module Api
  module V1
    # The web search box's results, each with its folder path ("" for the root),
    # so the CLI can name the file without fetching the folder tree. With
    # folder_id, only that folder and the folders below it are searched.
    class SearchesController < BaseController
      def show
        within = current_user.folders.find(params[:folder_id]) if params[:folder_id].present?
        # ::Notes, not Api::V1::Notes, which is the publications namespace.
        notes = ::Notes::Search.new(user: current_user, query: params[:q], within: within).results
        paths = Folder.path_map(current_user)

        render json: notes.map { |n| note_summary_json(n).merge(path: paths[n.folder_id]) }
      end
    end
  end
end
