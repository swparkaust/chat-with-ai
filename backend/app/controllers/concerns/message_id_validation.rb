module MessageIdValidation
  MAX_MESSAGE_IDS_PER_REQUEST = 1000

  # Sanitizes and validates an array of message IDs
  # Returns sanitized array if valid, nil otherwise
  #
  # @param message_ids [Array, Object] The message IDs to validate
  # @param max_count [Integer] Maximum number of IDs allowed
  # @return [Array<Integer>, nil] Sanitized positive integer IDs, or nil if invalid
  def sanitize_message_ids(message_ids, max_count: MAX_MESSAGE_IDS_PER_REQUEST)
    return nil unless message_ids.is_a?(Array)
    return nil if message_ids.size > max_count

    sanitized = message_ids.map(&:to_i).select { |id| id > 0 }
    sanitized.empty? ? nil : sanitized
  end
end
