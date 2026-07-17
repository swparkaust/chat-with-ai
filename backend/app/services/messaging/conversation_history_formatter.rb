module Messaging
  class ConversationHistoryFormatter
    # user_identifier is the display form the AI sees, e.g. "John (#123)"
    def self.format(messages, user_identifier:, ai_identifier: '나', include_read_status: true)
      messages.map do |msg|
        sender = msg.user_message? ? user_identifier : ai_identifier
        time = msg.created_at.strftime('%m/%d %H:%M')

        if include_read_status
          read_status = msg.read? ? '읽음' : '안읽음'
          "[#{time}] #{sender}: #{msg.content} (#{read_status})"
        else
          "[#{time}] #{sender}: #{msg.content}"
        end
      end.join("\n")
    end
  end
end
