module Ai
  class TimingDecider
    DEFAULT_DELAYS = {
      'thinking_before_response' => AppConstants::TIMING_DELAY_THINKING_BEFORE_RESPONSE,
      'thinking_before_read_only' => AppConstants::TIMING_DELAY_THINKING_BEFORE_READ_ONLY,
      'thinking_before_initiate' => AppConstants::TIMING_DELAY_THINKING_BEFORE_INITIATE
    }.freeze

    def initialize(router:)
      @router = router
    end

    def get_timing_decision(action_type, persona_state)
      system_context = Ai::SystemContextBuilder.new(persona_state, nil).build
      timing_prompt = build_timing_prompt(action_type)

      response = @router.call(task: :thinking_timing, system: system_context, prompt: timing_prompt)
      result = Ai::JsonParsing.parse_object(response.text)

      delay = result['delay_seconds']&.to_f || DEFAULT_DELAYS[action_type] || AppConstants::TIMING_DELAY_GENERIC_FALLBACK
      delay.clamp(AppConstants::THINKING_MIN_DELAY, AppConstants::THINKING_MAX_DELAY)
    rescue StandardError => e
      default_delay = DEFAULT_DELAYS[action_type] || AppConstants::TIMING_DELAY_GENERIC_FALLBACK
      Rails.logger.warn "Timing decision failed: #{e.message}, using default #{default_delay}s"
      default_delay
    end

    def get_fragment_delays(fragments, persona_state)
      return nil if fragments.blank?

      system_context = Ai::SystemContextBuilder.new(persona_state, nil).build
      delays_prompt = build_fragment_delays_prompt(fragments)

      response = @router.call(task: :fragment_timing, system: system_context, prompt: delays_prompt)
      result = Ai::JsonParsing.parse_object(response.text)

      delays = result['delays_seconds']
      return nil unless delays.is_a?(Array)

      delays.first(fragments.length).map do |delay|
        next nil unless delay.is_a?(Numeric)

        delay.to_f.clamp(AppConstants::FRAGMENT_MIN_DELAY, AppConstants::FRAGMENT_MAX_DELAY)
      end
    rescue StandardError => e
      Rails.logger.warn "Fragment delays decision failed: #{e.message}"
      nil
    end

    private

    def build_timing_prompt(action_type)
      action_description = case action_type
      when 'thinking_before_response'
        "You're about to respond to a message. How long should you wait before starting to type? (thinking time)"
      when 'thinking_before_read_only'
        "You're about to mark messages as read without responding. How long should you wait? (thinking time)"
      when 'thinking_before_initiate'
        "You're about to start a new conversation. How long should you wait before typing? (thinking time)"
      end

      <<~PROMPT
        Timing Decision: #{action_description}

        Consider:
        - Your personality (fast/slow typer, impulsive/thoughtful)
        - Your current emotional state (excited = faster, sad/tired = slower)
        - The situation and context

        Respond with ONLY a JSON object:
        {
            "delay_seconds": #{AppConstants::THINKING_MIN_DELAY}-#{AppConstants::THINKING_MAX_DELAY} (as a number, not a string)
        }

        Be realistic - most thinking delays should be #{AppConstants::THINKING_MIN_DELAY}-3 seconds.
      PROMPT
    end

    def build_fragment_delays_prompt(fragments)
      fragment_list = fragments.each_with_index.map do |fragment, index|
        "#{index + 1}. (#{fragment.length} chars) #{fragment}"
      end.join("\n")

      <<~PROMPT
        Timing Decision: You're about to send the following message fragments one by one. For each fragment, decide how long you should wait before sending it. (typing speed)

        Fragments:
        #{fragment_list}

        Consider:
        - Your personality (fast/slow typer, impulsive/thoughtful)
        - Your current emotional state (excited = faster, sad/tired = slower)
        - The situation and context
        - Natural human typing speed (even fast typers need time)
        - Fragment length (longer text = more typing time)

        Respond with ONLY a JSON object:
        {
            "delays_seconds": [one number per fragment, in order, each #{AppConstants::FRAGMENT_MIN_DELAY}-#{AppConstants::FRAGMENT_MAX_DELAY}]
        }

        The array must contain exactly #{fragments.length} numbers.
        Be realistic - most delays should be 1.5-4 seconds (to simulate realistic typing).
      PROMPT
    end

  end
end
