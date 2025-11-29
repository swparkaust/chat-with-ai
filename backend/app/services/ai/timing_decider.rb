module Ai
  class TimingDecider
    DEFAULT_DELAYS = {
      'thinking_before_response' => AppConstants::TIMING_DELAY_THINKING_BEFORE_RESPONSE,
      'thinking_before_read_only' => AppConstants::TIMING_DELAY_THINKING_BEFORE_READ_ONLY,
      'thinking_before_initiate' => AppConstants::TIMING_DELAY_THINKING_BEFORE_INITIATE,
      'delay_between_fragments' => AppConstants::TIMING_DELAY_BETWEEN_FRAGMENTS
    }.freeze

    def initialize(provider)
      @provider = provider
    end

    def get_timing_decision(action_type, persona_state, context = {})
      system_context = Ai::SystemContextBuilder.new(persona_state, nil).build
      timing_prompt = build_timing_prompt(system_context, action_type, context)

      result = @provider.generate_json(timing_prompt, temperature: AppConstants::AI_TEMPERATURE_FOCUSED)

      delay = result['delay_seconds']&.to_f || result[:delay_seconds]&.to_f || DEFAULT_DELAYS[action_type] || AppConstants::TIMING_DELAY_GENERIC_FALLBACK
      clamped_delay = [[delay, AppConstants::FRAGMENT_MIN_DELAY].max, AppConstants::FRAGMENT_MAX_DELAY].min

      clamped_delay
    rescue StandardError => e
      default_delay = DEFAULT_DELAYS[action_type] || AppConstants::TIMING_DELAY_GENERIC_FALLBACK
      Rails.logger.warn "Timing decision failed: #{e.message}, using default #{default_delay}s"
      default_delay
    end

    private

    def build_timing_prompt(system_context, action_type, context)
      context_str = if context.present?
        "\nAdditional context:\n" + context.map { |k, v| "- #{k}: #{v}" }.join("\n")
      else
        ""
      end

      action_description = case action_type
      when 'thinking_before_response'
        "You're about to respond to a message. How long should you wait before starting to type? (thinking time)"
      when 'thinking_before_read_only'
        "You're about to mark messages as read without responding. How long should you wait? (thinking time)"
      when 'thinking_before_initiate'
        "You're about to start a new conversation. How long should you wait before typing? (thinking time)"
      when 'delay_between_fragments'
        "You're sending message fragments. How long should you wait between sending fragments? (typing speed)"
      else
        "How long should you wait?"
      end

      <<~PROMPT
        #{system_context}

        Timing Decision: #{action_description}
        #{context_str}

        Consider:
        - Your personality (fast/slow typer, impulsive/thoughtful)
        - Your current emotional state (excited = faster, sad/tired = slower)
        - The situation and context
        - Natural human typing speed (even fast typers need time)
        - Fragment length (longer text = more typing time)

        Respond with ONLY a JSON object:
        {
            "delay_seconds": #{AppConstants::FRAGMENT_MIN_DELAY}-#{AppConstants::FRAGMENT_MAX_DELAY} (as a number, not a string)
        }

        Be realistic - most delays should be 1.5-4 seconds for fragments (to simulate realistic typing), #{AppConstants::FRAGMENT_MIN_DELAY}-3 for thinking.
      PROMPT
    end

  end
end
