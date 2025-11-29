class ConversationChannel < ApplicationCable::Channel
  include MessageIdValidation

  MAX_SCROLL_POSITION = 1_000_000

  def subscribed
    conversation = find_conversation
    return reject unless conversation

    stream_for conversation

    Rails.logger.info "User subscribed to conversation #{conversation.id}"
  end

  def unsubscribed
    conversation = find_conversation
    return unless conversation

    user_state = conversation.user_state
    user_state.stop_typing! if user_state&.typing?

    Rails.logger.info "User unsubscribed from conversation #{conversation.id}"
  end

  def typing(data)
    conversation = find_conversation
    return unless conversation
    return unless data.is_a?(Hash) && data.key?('is_typing')

    is_typing = !!data['is_typing']

    service = Messaging::TypingIndicatorService.new(conversation)

    if is_typing
      service.start_typing('user')
    else
      service.stop_typing('user')
    end
  end

  def update_focus(data)
    conversation = find_conversation
    return unless conversation
    return unless data.is_a?(Hash)

    user_state = conversation.user_state

    if data.key?('focused')
      focused = !!data['focused']
      user_state.set_focused(focused)
    end

    if data.key?('scroll_position')
      scroll_pos = data['scroll_position'].to_i
      scroll_pos = [[scroll_pos, 0].max, MAX_SCROLL_POSITION].min
      user_state.update_scroll(scroll_pos)
    end
  end

  def mark_as_read(data)
    conversation = find_conversation
    return unless conversation
    return unless data.is_a?(Hash)

    sanitized_ids = sanitize_message_ids(data['message_ids'])
    return if sanitized_ids.nil?

    service = Messaging::ReadReceiptManagerService.new(conversation)
    service.mark_messages_as_read(sanitized_ids, conversation.user_state)
  end

  private

  def find_conversation
    user = current_user
    return nil unless user

    conversation_id = params[:conversation_id]
    user.conversations.find_by(id: conversation_id)
  end
end
