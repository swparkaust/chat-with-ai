module Persona
  module Tools
    class ToolManager
      MAX_ITERATIONS = 5

      # Temperature setting for AI decision making (higher = more creative, lower = more focused)
      TOOL_DECISION_TEMPERATURE = 0.7

      def initialize(season)
        @season = season
        @tools = {}
        register_default_tools
      end

      def register_default_tools
        register_tool(CalendarTool)
        register_tool(ReminderTool)
        register_tool(MemoTool)
        register_tool(DiaryTool)
        register_tool(TodoTool)
        register_tool(ContactsTool)
        register_tool(WebSearchTool)
        register_tool(WebFetchTool)
      end

      def register_tool(tool_class)
        tool_name = tool_class.name.demodulize.underscore
        tool_state = @season.tool_states.find_or_create_by!(tool_name: tool_name)
        @tools[tool_name] = tool_class.new(tool_state)
      end

      def get_tool(name)
        @tools[name.to_s]
      end

      def all_tools
        @tools.values
      end

      def get_all_context
        contexts = @tools.map do |name, tool|
          "#{tool.name}:\n#{tool.get_context}"
        end.join("\n\n")

        contexts.presence || "No tool data yet"
      end

      def get_tools_description
        descriptions = @tools.map do |name, tool|
          desc = "- **#{name}** (#{tool.name}): #{tool.description}\n"
          tool.available_actions.each do |action|
            params = tool.get_action_params(action)
            if params.any?
              param_desc = params.map { |k, v| "\"#{k}\": #{v}" }.join(', ')
              desc += "  - #{action}: {#{param_desc}}\n"
            else
              desc += "  - #{action}\n"
            end
          end
          desc.rstrip
        end
        descriptions.join("\n")
      end

      def check_all_triggers
        current_time = Time.current
        all_triggers = []

        @tools.each do |name, tool|
          triggers = tool.check_triggers(current_time)
          all_triggers.concat(triggers) if triggers.any?
        end

        all_triggers
      end

      def execute_tool_chain(provider, system_context, recent_messages)
        results = []
        iteration = 0
        triggers = check_all_triggers

        loop do
          break if iteration >= MAX_ITERATIONS

          tool_actions = decide_tool_use(provider, system_context, recent_messages, triggers, results)

          break if tool_actions.empty?

          tool_actions.each do |action_spec|
            tool_name = action_spec['tool'] || action_spec[:tool]
            action = action_spec['action'] || action_spec[:action]
            params = action_spec['params'] || action_spec[:params] || {}
            reason = action_spec['reason'] || action_spec[:reason]

            tool_result = execute_tool_action(tool_name, action, params)
            results << {
              tool: tool_name,
              action: action,
              params: params,
              result: tool_result,
              reason: reason
            }
          end

          iteration += 1
        end

        results
      end

      private

      def decide_tool_use(provider, system_context, recent_messages, triggers, previous_results)
        prompt = build_tool_decision_prompt(system_context, recent_messages, triggers, previous_results)
        response = provider.generate_content(prompt, temperature: TOOL_DECISION_TEMPERATURE)

        parse_tool_decision(response)
      rescue StandardError => e
        Rails.logger.error "Tool decision failed: #{e.message}"
        []
      end

      def build_tool_decision_prompt(system_context, recent_messages, triggers, previous_results)
        tools_description = get_tools_description

        tool_context = get_all_context

        results_summary = ""
        if previous_results.any?
          results_summary = "\n\nPrevious tool results:\n"
          results_summary += previous_results.map do |r|
            "- #{r[:tool]} (#{r[:action]}): #{r[:result]}"
          end.join("\n")
        end

        <<~PROMPT
          #{system_context}

          Recent conversation:
          #{recent_messages}

          Available tools (use the exact name in **bold** as the "tool" value):
          #{tools_description}

          Triggers: #{triggers.any? ? triggers.join(', ') : 'None'}#{results_summary}

          Based on your current situation, conversation context, triggers, and any previous tool results, decide if you should use any tools.

          IMPORTANT RULES:
          1. Your tool context shows existing items with IDs in brackets [id] - check these first
          2. Before adding a new item, verify it doesn't already exist in your tool context
          3. If a similar item exists, use UPDATE with that ID instead of ADD to avoid duplicates
          4. Do NOT repeat actions already completed in previous iterations

          Consider:
          - Writing diary entries at night (especially if something significant happened)
          - Adding calendar events when plans are mentioned
          - Setting reminders for important tasks
          - Creating memos for useful information
          - Adding/completing todo items
          - Adding/updating contacts when people are mentioned:
            * For conversation participants (the person you're chatting with): Use FULL identifier format from system context
            * For other people (friends, family, etc.): Use their normal names
          - Searching the web when curious about something or need information
          - Fetching and reading web pages for articles or content you want to learn from
          - Following up on previous actions (e.g., fetch a URL from search results, save info to memo)
          - Human-like imperfection (forgetting to use tools, being lazy, etc.)

          Refer to the tool descriptions above for required parameters for each action.
          IMPORTANT: Do NOT include "id" in params for add actions - IDs are auto-generated.

          Respond with ONLY a JSON array of tool actions to perform (can be empty []):
          [
            {
              "tool": "tool_name",
              "action": "action_name",
              "params": { ... },
              "reason": "why you're doing this in Korean"
            }
          ]

          If you don't want to use any tools right now, return: []
        PROMPT
      end

      def parse_tool_decision(response)
        json_text = response.strip
        json_text = json_text[7..-1] if json_text.start_with?('```json')
        json_text = json_text[0..-4] if json_text.end_with?('```')
        json_text = json_text.strip

        parsed = JSON.parse(json_text)

        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse tool decision: #{e.message}"
        []
      end

      def execute_tool_action(tool_name, action, params)
        tool = get_tool(tool_name)
        return "Tool not found: #{tool_name}" unless tool

        action_params = params.is_a?(Hash) ? params.symbolize_keys : {}
        action_params[:action] = action

        tool.execute(action_params)
      rescue StandardError => e
        Rails.logger.error "Tool execution failed for #{tool_name}.#{action}: #{e.message}"
        "Error: #{e.message}"
      end
    end
  end
end
