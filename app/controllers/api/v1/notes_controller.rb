module Api
  module V1
    class NotesController < BaseController
      before_action -> { doorkeeper_authorize! :write }, only: %i[create update destroy]

      # Nested under a folder: that folder's notes, without bodies. Unnested, with
      # ?ids=1,2,3: those notes in full, so a sync client fetches every note its
      # manifest says changed in one request.
      def index
        if params[:folder_id]
          folder = current_user.folders.find(params[:folder_id])
          notes = current_user.notes.where(folder: folder).order(:updated_at)
          render json: notes.map { |n| note_summary_json(n) }
        else
          notes = current_user.notes.where(id: params.expect(:ids).split(","))
          render json: notes.map { |n| note_full_json(n) }
        end
      end

      def show
        note = current_user.notes.find(params[:id])
        render json: note_full_json(note)
      end

      def create
        note = current_user.notes.build(note_params)
        if note.save
          render json: note_full_json(note), status: :created
        else
          render json: { errors: note.errors }, status: :unprocessable_entity
        end
      end

      def update
        note = current_user.notes.find(params[:id])
        if note.update(note_params)
          render json: note_full_json(note)
        else
          render json: { errors: note.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        current_user.notes.find(params[:id]).destroy!
        head :no_content
      end

      private
        def note_params
          params.expect(note: [ :title, :body, :folder_id ])
        end
    end
  end
end
