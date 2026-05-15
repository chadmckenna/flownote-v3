module Api
  module V1
    class BaseController < ActionController::API
      before_action -> { doorkeeper_authorize! :read }

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

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
    end
  end
end
