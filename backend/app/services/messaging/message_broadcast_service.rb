module Messaging
  class MessageBroadcastService
    def initialize(conversation)
      @conversation = conversation
    end

    def broadcast_message(message)
      ConversationChannel.broadcast_to(
        @conversation,
        {
          type: 'message',
          message: message.as_json(
            only: [:id, :content, :sender_type, :created_at, :read_at, :is_fragment, :fragment_index]
          )
        }
      )
    end
  end
end
