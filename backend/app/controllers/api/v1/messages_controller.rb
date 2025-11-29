module Api
  module V1
    class MessagesController < ApplicationController
      include MessageIdValidation
      include InputSanitization

      before_action :authenticate_user!
      before_action :find_conversation

      def index
        limit = [[params[:limit].to_i, 1].max, AppConstants::MESSAGE_PAGE_SIZE_MAX].min
        limit = AppConstants::MESSAGE_PAGE_SIZE_DEFAULT if limit <= 1

        messages_query = @conversation.messages.order(created_at: :asc)

        if params[:before_id].present?
          before_id = params[:before_id].to_i
          return render json: { error: 'Invalid before_id' }, status: :bad_request if before_id <= 0
          messages_query = messages_query.where('id < ?', before_id)
        end

        messages = messages_query.limit(limit + 1).to_a

        has_more = messages.size > limit
        messages = messages.first(limit) if has_more

        render json: {
          messages: messages.map { |m| m.as_json(only: [:id, :content, :sender_type, :created_at, :read_at, :is_fragment, :fragment_index]) },
          has_more: has_more
        }
      end

      def create
        unless @conversation.active?
          return render json: { error: 'Conversation is not active' }, status: :forbidden
        end

        content = sanitize_content(params[:content])
        return render json: { error: 'Content required' }, status: :bad_request if content.blank?
        return render json: { error: "Message too long (max #{AppConstants::MESSAGE_CONTENT_MAX_LENGTH} characters)" }, status: :bad_request if content.length > AppConstants::MESSAGE_CONTENT_MAX_LENGTH

        message = @conversation.add_message('user', content)

        broadcast_service = Messaging::MessageBroadcastService.new(@conversation)
        broadcast_service.broadcast_message(message)

        AiDecisionJob.perform_later(@conversation.id)

        render json: {
          message: message.as_json(
            only: [:id, :content, :sender_type, :created_at, :read_at]
          )
        }, status: :created
      rescue StandardError => e
        Rails.logger.error "Message creation failed: #{e.message}"
        render json: { error: 'Failed to send message' }, status: :internal_server_error
      end

      def mark_as_read
        unless @conversation.active?
          return render json: { error: 'Conversation is not active' }, status: :forbidden
        end

        return render json: { error: 'message_ids required' }, status: :bad_request if params[:message_ids].blank?

        sanitized_ids = sanitize_message_ids(params[:message_ids])
        return render json: { error: 'Invalid or empty message_ids' }, status: :bad_request if sanitized_ids.nil?

        receipt_manager = Messaging::ReadReceiptManagerService.new(@conversation)
        count = receipt_manager.mark_messages_as_read(sanitized_ids, @conversation.user_state)

        render json: { marked_count: count }
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
