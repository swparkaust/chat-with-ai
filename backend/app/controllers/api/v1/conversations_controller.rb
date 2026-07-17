module Api
  module V1
    class ConversationsController < ApplicationController
      include SeasonJsonHelper

      before_action :authenticate_user!

      def index
        conversations = current_user.conversations
                                   .includes(season: { profile_picture_attachment: :blob })
                                   .joins(:season)
                                   .select(
                                     'conversations.*',
                                     '(SELECT COUNT(*) FROM messages WHERE messages.conversation_id = conversations.id AND messages.sender_type = \'ai\' AND messages.read_at IS NULL) as unread_count',
                                     '(SELECT content FROM messages WHERE messages.conversation_id = conversations.id ORDER BY created_at DESC LIMIT 1) as last_message_content'
                                   )
                                   .order(last_message_at: :desc)

        render json: {
          conversations: conversations.map do |conv|
            {
              id: conv.id,
              season_id: conv.season_id,
              season_number: conv.season.season_number,
              first_name: conv.season.first_name,
              full_name: conv.season.full_name,
              profile_picture: AttachmentUrl.for(conv.season.profile_picture),
              active: conv.active,
              last_message_at: conv.last_message_at,
              unread_count: conv.unread_count,
              last_message_preview: conv.last_message_content
            }
          end
        }
      end

      def show
        conversation = current_user.conversations.includes(:season).find(params[:id])

        render json: {
          conversation: conversation.as_json(only: [:id, :user_id, :season_id, :created_at, :updated_at]).merge(
            season: season_json(conversation.season)
          ),
          unread_user_count: conversation.unread_user_messages.count,
          unread_ai_count: conversation.unread_ai_messages.count
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Conversation not found' }, status: :not_found
      end

      def current
        season = Season.current

        unless season
          return render json: { error: 'No active season' }, status: :not_found
        end

        conversation = current_user.conversations.find_or_create_by!(season: season)

        if conversation.messages.empty?
          AiDecisionJob.restart_chain(conversation.id)
        end

        render json: {
          conversation: conversation.as_json(only: [:id, :user_id, :season_id, :created_at, :updated_at]).merge(
            season: season_json(season)
          )
        }
      end
    end
  end
end
