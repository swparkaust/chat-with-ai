module Messaging
  class TypingIndicatorService
    def initialize(conversation)
      @conversation = conversation
    end

    def start_typing(sender)
      user_state = @conversation.user_state
      user_state.start_typing! if sender == 'user'

      broadcast_typing_status(sender, true)
    end

    def stop_typing(sender)
      user_state = @conversation.user_state
      user_state.stop_typing! if sender == 'user'

      broadcast_typing_status(sender, false)
    end

    def broadcast_typing_status(sender, is_typing)
      ConversationChannel.broadcast_to(
        @conversation,
        {
          type: 'typing',
          sender_type: sender,
          is_typing: is_typing
        }
      )
    end
  end
end
