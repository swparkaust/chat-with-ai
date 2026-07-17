module Api
  module V1
    class UserStatesController < ApplicationController
      include ConversationScoped

      def update
        user_state = @conversation.user_state

        attrs = {}
        typing = nil

        # Cast, not !!: a form-encoded 'false' is a truthy String — keep the
        # boundary consistent with is_focused's ActiveRecord column cast.
        # cast returns nil for garbage, which the guards below then skip.
        typing = ActiveModel::Type::Boolean.new.cast(params[:typing]) unless params[:typing].nil?
        attrs[:typing] = typing unless typing.nil?

        unless params[:focused].nil?
          attrs[:is_focused] = params[:focused]
        end

        if params[:scroll_position].present?
          attrs[:scroll_position] = params[:scroll_position]
        end

        user_state.update!(attrs) if attrs.any?

        unless typing.nil?
          Messaging::TypingIndicatorService.new(@conversation).broadcast_typing_status('user', typing)
        end

        render json: { success: true }
      end
    end
  end
end
