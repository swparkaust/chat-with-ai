module Api
  module V1
    class UsersController < ApplicationController
      include UserJsonHelper
      include InputSanitization

      before_action :authenticate_user!

      def show
        render json: {
          user: user_json(current_user).merge(created_at: current_user.created_at)
        }
      end

      def update
        if params[:user][:profile_picture_signed_id].present?
          begin
            blob = ActiveStorage::Blob.find_signed(params[:user][:profile_picture_signed_id])
            current_user.profile_picture.attach(blob)
          rescue ActiveRecord::RecordNotFound
            return render json: { error: 'Upload token expired or invalid, please try again' }, status: :bad_request
          end
        end

        sanitized_params = {}
        sanitized_params[:name] = sanitize_content(params[:user][:name]) if params[:user][:name].present?
        sanitized_params[:status_message] = sanitize_content(params[:user][:status_message]) if params[:user][:status_message].present?

        if current_user.update(sanitized_params)
          render json: {
            user: user_json(current_user)
          }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:name, :status_message)
      end
    end
  end
end
