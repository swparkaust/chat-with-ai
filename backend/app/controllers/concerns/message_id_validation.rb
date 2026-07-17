module MessageIdValidation
  MAX_MESSAGE_IDS_PER_REQUEST = 1000

  # Returns positive integer IDs, or nil when the input is invalid or empty
  def sanitize_message_ids(message_ids, max_count: MAX_MESSAGE_IDS_PER_REQUEST)
    return nil unless message_ids.is_a?(Array)
    return nil if message_ids.size > max_count

    sanitized = message_ids.map(&:to_i).select { |id| id > 0 }
    sanitized.empty? ? nil : sanitized
  end
end
