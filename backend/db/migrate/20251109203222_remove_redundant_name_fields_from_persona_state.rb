class RemoveRedundantNameFieldsFromPersonaState < ActiveRecord::Migration[8.0]
  def up
    # Remove first_name, last_name, and status_message from all persona_states' state_data
    # These fields are already stored in the seasons table
    PersonaState.find_each do |persona_state|
      state_data = persona_state.state_data.dup
      state_data.delete('first_name')
      state_data.delete('last_name')
      state_data.delete('status_message')
      persona_state.update_column(:state_data, state_data)
    end
  end

  def down
    # Restore name fields from season to state_data
    PersonaState.find_each do |persona_state|
      season = persona_state.season
      next unless season

      state_data = persona_state.state_data.dup
      state_data['first_name'] = season.first_name if season.first_name
      state_data['last_name'] = season.last_name if season.last_name
      state_data['status_message'] = season.status_message if season.status_message
      persona_state.update_column(:state_data, state_data)
    end
  end
end
