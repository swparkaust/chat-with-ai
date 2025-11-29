module Api
  module V1
    class ProfilesController < ApplicationController
      include InputSanitization

      before_action :authenticate_user!

      def ai_profile
        season = Season.current

        unless season
          return render json: { error: 'No active season' }, status: :not_found
        end

        persona_state = season.persona_state

        render json: {
          profile: {
            first_name: season.first_name,
            last_name: season.last_name,
            full_name: season.full_name,
            profile_picture: season.profile_picture.attached? ? url_for(season.profile_picture) : nil,
            status_message: season.status_message,
            age: persona_state.age,
            occupation: persona_state.state_data['occupation'],
            interests: persona_state.state_data['interests'],
            personality_traits: persona_state.state_data['personality_traits']
          }
        }
      end

      def my_profile
        render json: {
          profile: {
            name: current_user.name,
            status_message: current_user.status_message,
            profile_picture: current_user.profile_picture.attached? ? url_for(current_user.profile_picture) : nil
          }
        }
      end

      def update_my_profile
        if params[:profile][:profile_picture_signed_id].present?
          begin
            blob = ActiveStorage::Blob.find_signed(params[:profile][:profile_picture_signed_id])
            current_user.profile_picture.attach(blob)
          rescue ActiveRecord::RecordNotFound
            return render json: { error: 'Upload token expired or invalid, please try again' }, status: :bad_request
          end
        end

        sanitized_params = {}
        sanitized_params[:name] = sanitize_content(params[:profile][:name]) if params[:profile][:name].present?
        sanitized_params[:status_message] = sanitize_content(params[:profile][:status_message]) if params[:profile][:status_message].present?

        if current_user.update(sanitized_params)
          render json: {
            profile: {
              name: current_user.name,
              status_message: current_user.status_message,
              profile_picture: current_user.profile_picture.attached? ? url_for(current_user.profile_picture) : nil
            }
          }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.require(:profile).permit(:name, :status_message)
      end
    end
  end
end
