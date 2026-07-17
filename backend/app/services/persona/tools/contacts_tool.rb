module Persona
  module Tools
    class ContactsTool < BaseTool
      def name
        "Contacts"
      end

      def description
        "Relationship and contact management"
      end

      def available_actions
        ['add', 'remove', 'update', 'mark_contacted', 'search', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { "name" => "string", "relationship?" => "string", "phone?" => "string", "birthday?" => "YYYY-MM-DD", "notes?" => "string", "importance?" => "normal|high" }
        when 'remove'
          { "id" => "string" }
        when 'update'
          { "id" => "string", "name?" => "string", "relationship?" => "string", "phone?" => "string", "birthday?" => "YYYY-MM-DD", "notes?" => "string", "importance?" => "normal|high" }
        when 'mark_contacted'
          { "id" => "string" }
        when 'search'
          { "query" => "string" }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        contacts = items('contacts')
        return "No contacts" if contacts.empty?

        important = contacts.select { |c| c['importance'] == 'high' }.first(3)
        regular = contacts.select { |c| c['importance'] != 'high' }.first(2)

        (important + regular).map do |c|
          relationship = c['relationship'] ? " (#{c['relationship']})" : ''
          last_contact = c['last_contact'] ? " - 마지막 연락: #{c['last_contact']}" : ''
          format_item_line(c, "#{c['name']}#{relationship}#{last_contact}")
        end.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_contact(params)
        when 'remove'
          remove_contact(params[:id])
        when 'update'
          update_contact(params)
        when 'mark_contacted'
          mark_contacted(params[:id])
        when 'search'
          search_contacts(params[:query])
        when 'list'
          list_contacts
        else
          "Unknown action"
        end
      end

      def check_triggers(current_time)
        contacts = items('contacts')
        today = current_time.to_date
        triggers = []

        contacts.each do |contact|
          next unless contact['birthday']

          birthday = safe_parse_date(contact['birthday'])
          next unless birthday

          if birthday.month == today.month && (birthday.day - today.day).between?(0, 3)
            # Once per contact per day — the window spans four days and
            # every fire wakes all parked decision loops
            next if contact['birthday_notified_on'] == today.iso8601

            triggers << "Upcoming birthday: #{contact['name']} on #{birthday.strftime('%m/%d')}"
            contact['birthday_notified_on'] = today.iso8601
          end
        end

        # Non-atomic — see JsonbStateAccessor#set_state
        set_data('contacts', contacts) if triggers.any?
        triggers
      end

      private

      def add_contact(params)
        return invalid_date_error(params[:birthday]) if params[:birthday] && !safe_parse_date(params[:birthday])

        add_item('contacts',
          'name' => params[:name],
          'relationship' => params[:relationship],
          'phone' => params[:phone],
          'birthday' => params[:birthday],
          'notes' => params[:notes],
          'importance' => params[:importance] || 'normal',
          'last_contact' => Time.current.to_s
        )
        "Contact added"
      end

      def update_contact(params)
        return invalid_date_error(params[:birthday]) if params[:birthday] && !safe_parse_date(params[:birthday])

        contact = update_item('contacts', params[:id]) do |c|
          c.merge!(params.except(:id, :action).stringify_keys)
        end

        contact ? "Contact updated" : "Contact not found"
      end

      def search_contacts(query)
        results = items('contacts').select { |c| c['name'].include?(query) }
        results.map { |c| format_item_line(c, "#{c['name']} - #{c['relationship']}") }.join("\n")
      end

      def list_contacts
        items('contacts').map { |c| format_item_line(c, "#{c['name']} (#{c['relationship']})") }.join("\n")
      end

      def mark_contacted(id)
        contact = update_item('contacts', id) { |c| c['last_contact'] = Time.current.to_s }
        contact ? "Contact marked as contacted" : "Contact not found"
      end

      def remove_contact(id)
        remove_item('contacts', id)
        "Contact removed"
      end
    end
  end
end
