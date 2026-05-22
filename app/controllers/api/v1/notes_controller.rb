module Api
  module V1
    class NotesController < BaseController
      before_action -> { doorkeeper_authorize! :write }, only: %i[create update destroy]

      def index
        folder = current_user.folders.find(params[:folder_id])
        render json: folder.notes.order(:updated_at).map { |n| note_summary_json(n) }
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

        def note_summary_json(note)
          {
            id: note.id,
            title: note.title,
            folder_id: note.folder_id,
            updated_at: note.updated_at.iso8601
          }
        end

        def note_full_json(note)
          note_summary_json(note).merge(body: note.body.to_s)
        end
    end
  end
end
