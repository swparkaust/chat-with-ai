module Messaging
  class ConversationHistoryFormatter
    # Format conversation messages with user identifier, timestamp, and optional read status
    #
    # @param messages [ActiveRecord::Relation<Message>] Messages to format
    # @param user_identifier [String] How to identify the user (e.g., "John (#123)")
    # @param ai_identifier [String] How to identify the AI (default: "나")
    # @param include_read_status [Boolean] Whether to include read status (default: true)
    # @return [String] Formatted conversation history
    def self.format(messages, user_identifier:, ai_identifier: '나', include_read_status: true)
      messages.map do |msg|
        sender = msg.user_message? ? user_identifier : ai_identifier
        time = msg.created_at.strftime('%m/%d %H:%M')

        if include_read_status
          read_status = msg.read_at.present? ? '읽음' : '안읽음'
          "[#{time}] #{sender}: #{msg.content} (#{read_status})"
        else
          "[#{time}] #{sender}: #{msg.content}"
        end
      end.join("\n")
    end
  end
end
