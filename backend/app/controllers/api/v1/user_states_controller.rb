module Api
  module V1
    class UserStatesController < ApplicationController
      before_action :authenticate_user!
      before_action :find_conversation

      def update
        user_state = @conversation.user_state

        if params[:typing].present?
          if params[:typing]
            Messaging::TypingIndicatorService.new(@conversation).start_typing('user')
          else
            Messaging::TypingIndicatorService.new(@conversation).stop_typing('user')
          end
        end

        if params[:focused].present?
          user_state.set_focused(params[:focused])
        end

        if params[:scroll_position].present?
          user_state.update_scroll(params[:scroll_position])
        end

        user_state.touch_seen

        render json: { success: true }
      rescue StandardError => e
        Rails.logger.error "User state update failed: #{e.message}"
        render json: { error: 'Failed to update state' }, status: :internal_server_error
      end

      private

      def find_conversation
        @conversation = current_user.conversations.find(params[:conversation_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Conversation not found' }, status: :not_found
      end
    end
  end
end
