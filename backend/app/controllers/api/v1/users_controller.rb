module Api
  module V1
    class UsersController < ApplicationController
      include UserJsonHelper
      include ProfileUpdatable

      before_action :authenticate_user!

      def show
        render json: {
          user: user_json(current_user).merge(created_at: current_user.created_at)
        }
      end

      def update
        return unless apply_profile_update(:user)

        render json: {
          user: user_json(current_user)
        }
      end
    end
  end
end
