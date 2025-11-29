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
        contacts = get_data('contacts') || []
        return "No contacts" if contacts.empty?

        important = contacts.select { |c| c['importance'] == 'high' }.first(3)
        regular = contacts.select { |c| c['importance'] != 'high' }.first(2)

        (important + regular).map do |c|
          relationship = c['relationship'] ? " (#{c['relationship']})" : ''
          last_contact = c['last_contact'] ? " - 마지막 연락: #{c['last_contact']}" : ''
          "#{c['name']}#{relationship}#{last_contact}"
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
        contacts = get_data('contacts') || []
        triggers = []

        contacts.each do |contact|
          next unless contact['birthday']

          birthday = Date.parse(contact['birthday'])
          today = current_time.to_date

          if birthday.month == today.month && (birthday.day - today.day).between?(0, 3)
            triggers << "Upcoming birthday: #{contact['name']} on #{birthday.strftime('%m/%d')}"
          end
        end

        triggers
      end

      private

      def add_contact(params)
        contacts = get_data('contacts') || []
        contacts << {
          'id' => SecureRandom.uuid,
          'name' => params[:name],
          'relationship' => params[:relationship],
          'phone' => params[:phone],
          'birthday' => params[:birthday],
          'notes' => params[:notes],
          'importance' => params[:importance] || 'normal',
          'last_contact' => Time.current.to_s,
          'created_at' => Time.current.to_s
        }
        set_data('contacts', contacts)
        "Contact added"
      end

      def update_contact(params)
        contacts = get_data('contacts') || []
        contact = contacts.find { |c| c['id'] == params[:id] }

        if contact
          contact.merge!(params.except(:id, :action))
          set_data('contacts', contacts)
          "Contact updated"
        else
          "Contact not found"
        end
      end

      def search_contacts(query)
        contacts = get_data('contacts') || []
        results = contacts.select { |c| c['name'].include?(query) }
        results.map { |c| "#{c['name']} - #{c['relationship']}" }.join("\n")
      end

      def list_contacts
        contacts = get_data('contacts') || []
        contacts.map { |c| "#{c['name']} (#{c['relationship']})" }.join("\n")
      end

      def mark_contacted(id)
        contacts = get_data('contacts') || []
        contact = contacts.find { |c| c['id'] == id }

        return "Contact not found" unless contact

        contact['last_contact'] = Time.current.to_s
        set_data('contacts', contacts)
        "Contact marked as contacted"
      end

      def remove_contact(id)
        contacts = get_data('contacts') || []
        contacts.reject! { |c| c['id'] == id }
        set_data('contacts', contacts)
        "Contact removed"
      end
    end
  end
end
