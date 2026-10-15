module Api
  module V1
    module Notes
      class PublicationsController < BaseController
        before_action -> { doorkeeper_authorize! :write }
        before_action :set_note

        def create
          if current_user.username.blank?
            render json: { error: "username_required", message: "Set a username at #{profile_url} before publishing notes." },
              status: :unprocessable_entity
          else
            @note.publish!
            render json: note_full_json(@note)
          end
        end

        def destroy
          @note.unpublish!
          render json: note_full_json(@note)
        end

        private
          def set_note
            @note = current_user.notes.find(params[:note_id])
          end
      end
    end
  end
end
