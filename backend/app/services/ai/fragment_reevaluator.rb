module Ai
  class FragmentReevaluator
    def initialize(provider)
      @provider = provider
    end

    def reevaluate_remaining_fragments(remaining_fragments, conversation, just_sent_fragments)
      return { continue: true, fragments: remaining_fragments } if remaining_fragments.blank?

      history_text = build_history_text(conversation)
      just_sent_text = build_just_sent_text(just_sent_fragments)
      remaining_text = build_remaining_text(remaining_fragments)

      system_context = Ai::SystemContextBuilder.new(conversation.season.persona_state, conversation).build
      reevaluation_prompt = build_reevaluation_prompt(system_context, history_text, just_sent_text, remaining_text)

      result = @provider.generate_json(reevaluation_prompt, temperature: AppConstants::AI_TEMPERATURE_FOCUSED)

      should_continue = result['should_continue'] || result[:should_continue] || true
      updated_fragments = result['updated_fragments'] || result[:updated_fragments]
      reason = result['reason'] || result[:reason] || 'No reason provided'

      if !should_continue
        Rails.logger.info "Reevaluation: STOP sending (reason: #{reason})"
        { continue: false, fragments: [], reason: reason }
      elsif updated_fragments && updated_fragments.is_a?(Array)
        Rails.logger.info "Reevaluation: Updated to #{updated_fragments.length} fragments (reason: #{reason})"
        { continue: true, fragments: updated_fragments, reason: reason }
      else
        { continue: true, fragments: remaining_fragments, reason: reason }
      end
    rescue StandardError => e
      Rails.logger.error "Fragment reevaluation failed: #{e.message}"
      { continue: true, fragments: remaining_fragments }
    end

    private

    def build_history_text(conversation)
      user = conversation.user
      recent_messages = conversation.messages.order(created_at: :desc).limit(AppConstants::CONTEXT_MESSAGES_FOR_REEVALUATION).reverse

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

    def build_reevaluation_prompt(system_context, history_text, just_sent_text, remaining_text)
      <<~PROMPT
        #{system_context}

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
