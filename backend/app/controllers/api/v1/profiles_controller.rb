module Api
  module V1
    class ProfilesController < ApplicationController
      include UserJsonHelper
      include ProfileUpdatable

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
            profile_picture: AttachmentUrl.for(season.profile_picture),
            status_message: season.status_message,
            age: persona_state.age,
            occupation: persona_state.state_data['occupation'],
            interests: persona_state.state_data['interests'],
            personality_traits: persona_state.state_data['personality_traits']
          }
        }
      end

      def my_profile
        render json: { profile: user_json(current_user) }
      end

      def update_my_profile
        return unless apply_profile_update(:profile)

        render json: { profile: user_json(current_user) }
      end
    end
  end
end
