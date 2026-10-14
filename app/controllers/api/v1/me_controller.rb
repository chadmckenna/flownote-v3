module Api
  module V1
    class MeController < BaseController
      def show
        render json: { id: current_user.id, email: current_user.email_address, username: current_user.username }
      end
    end
  end
end
