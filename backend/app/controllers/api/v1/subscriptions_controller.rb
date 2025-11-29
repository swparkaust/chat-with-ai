module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :authenticate_user!

      MAX_SUBSCRIPTION_KEY_LENGTH = 500

      def create
        begin
          endpoint = subscription_params[:endpoint]
          unless endpoint =~ URI::DEFAULT_PARSER.make_regexp
            return render json: { error: 'Invalid endpoint URL' }, status: :bad_request
          end

          p256dh_key = subscription_params[:p256dh_key]
          auth_key = subscription_params[:auth_key]

          if p256dh_key.blank? || auth_key.blank?
            return render json: { error: 'Keys required' }, status: :bad_request
          end

          if p256dh_key.length > MAX_SUBSCRIPTION_KEY_LENGTH || auth_key.length > MAX_SUBSCRIPTION_KEY_LENGTH
            return render json: { error: 'Keys too long' }, status: :bad_request
          end

          subscription = current_user.push_subscriptions.find_or_initialize_by(
            endpoint: endpoint
          )

          subscription.assign_attributes(
            p256dh_key: p256dh_key,
            auth_key: auth_key
          )

          if subscription.save
            render json: { subscription: subscription.as_json(only: [:id, :endpoint]) }, status: :created
          else
            render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActionController::ParameterMissing => e
          render json: { error: "Missing required parameter: #{e.param}" }, status: :bad_request
        rescue ActiveRecord::RecordNotUnique
          render json: { error: 'Subscription already exists' }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "Subscription creation failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: 'Failed to create subscription' }, status: :internal_server_error
        end
      end

      def destroy
        begin
          subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])

          if subscription
            subscription.destroy!
            render json: { message: 'Subscription removed' }
          else
            render json: { error: 'Subscription not found' }, status: :not_found
          end
        rescue ActiveRecord::RecordNotDestroyed => e
          render json: { error: "Failed to remove subscription: #{e.message}" }, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "Subscription deletion failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: 'Failed to remove subscription' }, status: :internal_server_error
        end
      end

      private

      def subscription_params
        params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key)
      end
    end
  end
end
