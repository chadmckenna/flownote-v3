module Api
  module V1
    # What a sync client needs to see what changed under a folder, in one
    # request: the folder subtree, and every note in it with a hash of its body
    # in place of the body. The client then fetches only the notes whose hash
    # moved, via GET /api/v1/notes?ids=.
    class ManifestsController < BaseController
      def show
        folder_ids = current_user.folders.find(params[:folder_id]).subtree_ids
        folders = current_user.folders.where(id: folder_ids).order(:parent_id, :name)
        notes = current_user.notes.where(folder_id: folder_ids).order(:id)

        render json: {
          folders: folders.map { |f| folder_json(f) },
          notes: notes.map { |n| note_summary_json(n).merge(body_sha256: Digest::SHA256.hexdigest(n.body.to_s)) }
        }
      end
    end
  end
end
