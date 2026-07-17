module Ai
  class FragmentReevaluator
    def initialize(router:)
      @router = router
    end

    def reevaluate_remaining_fragments(remaining_fragments, conversation, just_sent_fragments)
      return { continue: true } if remaining_fragments.blank?

      history_text = build_history_text(conversation)
      just_sent_text = build_just_sent_text(just_sent_fragments)
      remaining_text = build_remaining_text(remaining_fragments)

      system_context = Ai::SystemContextBuilder.new(conversation.season.persona_state, conversation).build
      reevaluation_prompt = build_reevaluation_prompt(history_text, just_sent_text, remaining_text)

      response = @router.call(task: :fragment_reevaluation, system: system_context, prompt: reevaluation_prompt)

      # A blank response means the model never saw the thread — the caller's
      # interrupt baseline must not advance on it
      return { continue: true, error: true } if response.text.blank?

      result = Ai::JsonParsing.parse_object(response.text)

      should_continue = result.fetch('should_continue', true)
      # Sanitize like MessageGenerator#parse_fragments: spliced fragments are
      # serialized into job args, so a nil/blank/numeric element would crash
      # every retry of the remaining chain identically
      updated_fragments = result['updated_fragments']
      if updated_fragments.is_a?(Array)
        updated_fragments = updated_fragments.map { |f| f.to_s.strip }.reject(&:blank?)
        # Sanitized-to-empty is an explicit retraction — stop, never resend
        # the originals
        should_continue = false if updated_fragments.empty?
      end
      reason = result['reason'] || 'No reason provided'

      if !should_continue
        Rails.logger.info "Reevaluation: STOP sending (reason: #{reason})"
        { continue: false, reason: reason }
      elsif updated_fragments.is_a?(Array)
        Rails.logger.info "Reevaluation: Updated to #{updated_fragments.length} fragments (reason: #{reason})"
        { continue: true, fragments: updated_fragments, reason: reason }
      else
        { continue: true, reason: reason }
      end
    rescue StandardError => e
      Rails.logger.error "Fragment reevaluation failed: #{e.message}"
      { continue: true, error: true }
    end

    private

    def build_history_text(conversation)
      user = conversation.user
      recent_messages = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_REEVALUATION)

      Messaging::ConversationHistoryFormatter.format(
        recent_messages,
        user_identifier: user.identifier
      )
    end

    def build_just_sent_text(just_sent)
      just_sent.map { |msg| "나 (방금 보냄): #{msg}" }.join("\n")
    end

    def build_remaining_text(remaining)
      remaining.map { |msg| "[보낼 예정] #{msg}" }.join("\n")
    end

    def build_reevaluation_prompt(history_text, just_sent_text, remaining_text)
      <<~PROMPT
        Current conversation state:
        #{history_text}

        You just sent these messages:
        #{just_sent_text}

        You were planning to send these remaining messages:
        #{remaining_text}

        Check if anything has changed (new messages from user, conversation interrupted, etc.).

        Should you:
        1. Continue with remaining fragments as-is
        2. Modify the remaining fragments
        3. Stop sending (if user interrupted or context changed)

        Respond with ONLY a JSON object:
        {
            "should_continue": true/false,
            "reason": "brief reason in Korean",
            "updated_fragments": ["array", "of", "messages"] or null if continuing as-is
        }

        If should_continue is false, you're stopping the current message sequence.
        If updated_fragments is provided, use those instead of the original remaining fragments.
      PROMPT
    end

  end
end
