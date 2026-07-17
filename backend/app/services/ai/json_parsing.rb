module Ai
  # Shared parsing for AI responses expected to contain JSON. Extracts the
  # outermost object or array (models wrap JSON in markdown fences or append
  # trailing text), returning {} on unparseable or blank input.
  module JsonParsing
    module_function

    # For callers expecting a JSON object: models sometimes wrap the object
    # in a one-element list, so unwrap it; anything non-Hash becomes {} (the
    # uniform failure value). Array consumers use parse_json_response.
    def parse_object(response_text)
      data = parse_json_response(response_text)
      data = data.first if data.is_a?(Array)
      data.is_a?(Hash) ? data : {}
    end

    # A scalar for an array field would poison persisted state (a non-array
    # emotions value breaks every subsequent context build with no self-heal
    # path), so coerce at the parse boundary. A real array is honored even
    # when empty (an explicit clear); scalar junk that coerces to nothing is
    # dropped as untrustworthy.
    def coerce_string_array!(hash, key)
      return unless hash.key?(key)

      raw = hash[key]
      cleaned = Array(raw).map(&:to_s).reject(&:blank?)
      if raw.is_a?(Array) || cleaned.any?
        hash[key] = cleaned
      else
        hash.delete(key)
      end
    end

    def parse_json_response(response_text)
      return {} if response_text.blank?

      json_text = response_text.strip

      first_brace = json_text.index('{')
      last_brace = json_text.rindex('}')
      first_bracket = json_text.index('[')
      last_bracket = json_text.rindex(']')

      object_found = first_brace && last_brace
      array_found = first_bracket && last_bracket

      if array_found && (!object_found || (first_bracket < first_brace && last_bracket > last_brace))
        json_text = json_text[first_bracket..last_bracket]
      elsif object_found
        json_text = json_text[first_brace..last_brace]
      else
        json_text = json_text[7..-1] if json_text.start_with?('```json')
        json_text = json_text[0..-4] if json_text.end_with?('```')
      end

      JSON.parse(json_text.strip)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response: #{e.message}"
      Rails.logger.error "Response text: #{response_text}"
      {}
    end
  end
end
