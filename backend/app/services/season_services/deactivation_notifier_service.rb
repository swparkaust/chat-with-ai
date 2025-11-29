module SeasonServices
  class DeactivationNotifierService
    def self.check_and_notify
      current_season = ::Season.current

      return unless current_season
      return unless current_season.should_warn_deactivation?

      Rails.logger.info "Sending deactivation warning for season #{current_season.season_number}"

      send_deactivation_messages(current_season)
      current_season.mark_deactivation_warned!

      true
    end

    def self.send_deactivation_messages(season)
      conversations = season.conversations.active_conversations
      provider = Ai::ProviderFactory.default
      generator = Ai::MessageGenerator.new(provider)

      conversations.find_each do |conversation|
        send_deactivation_message_to_conversation(conversation, generator)
      end
    end

    private

    def self.send_deactivation_message_to_conversation(conversation, generator)
      persona_state = conversation.season.persona_state
      system_context = Ai::SystemContextBuilder.new(persona_state, conversation).build

      farewell_prompt = build_farewell_prompt(system_context, conversation.user)

      begin
        provider = Ai::ProviderFactory.default
        response_text = provider.generate_content(farewell_prompt, temperature: 1.0)
        fragments = response_text.strip.split("\n").map(&:strip).reject(&:blank?)

        FragmentSendJob.perform_later(conversation.id, fragments)

        Rails.logger.info "Sent deactivation message to conversation #{conversation.id}"
      rescue StandardError => e
        Rails.logger.error "Failed to send deactivation message: #{e.message}"
      end
    end

    def self.build_farewell_prompt(system_context, user)
      user_identifier = user.identifier

      <<~PROMPT
        #{system_context}

        You need to gently let #{user_identifier} know that you'll be leaving soon (in about 2 weeks).

        IMPORTANT:
        - Do NOT reveal you are an AI
        - Make it natural and personal (e.g., moving away, life changes, etc.)
        - Be emotional and authentic to your personality
        - Give them time to say goodbye
        - Fragment your message naturally

        This is a personal goodbye message. Write it naturally in Korean messaging style, one fragment per line.
      PROMPT
    end
  end
end
