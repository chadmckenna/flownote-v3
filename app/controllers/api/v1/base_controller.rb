module Api
  module V1
    class BaseController < ActionController::API
      before_action -> { doorkeeper_authorize! :read }

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      # The unique indexes catch what validations miss when two requests race.
      rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict

      private

      def current_user
        @current_user ||= User.find(doorkeeper_token.resource_owner_id)
      end

      def render_not_found(error)
        render json: { error: "not_found", message: error.message }, status: :not_found
      end

      def render_bad_request(error)
        render json: { error: "bad_request", message: error.message }, status: :bad_request
      end

      def render_conflict
        render json: { error: "conflict", message: "A note or folder with that name already exists there." }, status: :unprocessable_entity
      end

      def folder_json(folder)
        {
          id: folder.id,
          name: folder.name,
          parent_id: folder.parent_id,
          root: folder.root?,
          updated_at: folder.updated_at.iso8601
        }
      end

      def note_summary_json(note)
        {
          id: note.id,
          title: note.title,
          folder_id: note.folder_id,
          updated_at: note.updated_at.iso8601,
          public_url: public_url(note)
        }
      end

      def note_full_json(note)
        note_summary_json(note).merge(body: note.body.to_s)
      end

      # Nil while the note is unpublished, and while its owner has no username,
      # which the URL embeds.
      def public_url(note)
        public_note_url(username: current_user.username, slug: note.slug) if note.published? && current_user.username.present?
      end
    end
  end
end
