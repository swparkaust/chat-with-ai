module Api
  module V1
    class DeviceLinksController < ApplicationController
      before_action :authenticate_user!, only: [:create]

      LINK_CODE_TTL = 10.minutes
      # No I/O/0/1: codes get read aloud or retyped across devices
      CODE_ALPHABET = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z 2 3 4 5 6 7 8 9].freeze
      CODE_LENGTH = 6

      def create
        code = generate_unique_code
        unless code
          return render json: { error: 'Failed to generate code' }, status: :service_unavailable
        end

        render json: { code: code, expires_in: LINK_CODE_TTL.to_i }
      end

      # Unauthenticated by design: the claiming install has no identity yet —
      # the short-lived single-use code IS the bearer credential. Accepted
      # residuals: no rate limit (32^6 space against a 10-minute TTL), and
      # non-idempotency — GETDEL spends the code even if the response is
      # lost in transit; recovery is re-issuing from the source device.
      def claim
        normalized = params.require(:code).to_s.upcase.gsub(/[^A-Z2-9]/, '')
        device_id = normalized.length == CODE_LENGTH ? DistributedLockManager.consume(link_key(normalized)) : nil

        if device_id
          # Self-clean the auto-created pre-claim identity (the claiming
          # install authenticated as a fresh user before adopting this one);
          # the conversations guard makes destroying history impossible
          if current_user && current_user.device_id != device_id && current_user.conversations.none?
            current_user.destroy
          end
          render json: { device_id: device_id }
        else
          render json: { error: 'Invalid or expired code' }, status: :not_found
        end
      end

      private

      def generate_unique_code
        3.times do
          code = Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.size)] }.join
          return code if DistributedLockManager.store_once(link_key(code), current_user.device_id, ttl: LINK_CODE_TTL)
        end
        nil
      end

      def link_key(code)
        "device_link:#{code}"
      end
    end
  end
end
