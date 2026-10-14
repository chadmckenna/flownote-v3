module Api
  module V1
    # The web search box's results, each with its folder path ("" for the root),
    # so the CLI can name the file without fetching the folder tree.
    class SearchesController < BaseController
      def show
        # ::Notes, not Api::V1::Notes, which is the publications namespace.
        notes = ::Notes::Search.new(user: current_user, query: params[:q]).results
        paths = Folder.path_map(current_user)

        render json: notes.map { |n| note_summary_json(n).merge(path: paths[n.folder_id]) }
      end
    end
  end
end
