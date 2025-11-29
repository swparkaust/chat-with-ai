module Api
  module V1
    class AuthController < ApplicationController
      include UserJsonHelper

      def authenticate
        device_id = request.headers['X-Device-ID']&.to_s&.strip

        if device_id.blank?
          return render json: { error: 'Device ID required' }, status: :bad_request
        end

        if device_id.length > 255
          return render json: { error: 'Device ID too long' }, status: :bad_request
        end

        unless device_id =~ /\A[a-zA-Z0-9\-_]{8,255}\z/
          return render json: { error: 'Invalid Device ID format' }, status: :bad_request
        end

        user = User.find_or_create_by!(device_id: device_id) do |u|
          u.last_seen_at = Time.current
        end

        user.touch_last_seen

        render json: {
          user: user_json(user),
          authenticated: true
        }
      rescue StandardError => e
        Rails.logger.error "Authentication failed: #{e.message}"
        render json: { error: 'Authentication failed' }, status: :internal_server_error
      end

      def verify
        user = current_user

        if user
          render json: {
            user: user_json(user),
            authenticated: true
          }
        else
          render json: { authenticated: false }, status: :unauthorized
        end
      end
    end
  end
end
