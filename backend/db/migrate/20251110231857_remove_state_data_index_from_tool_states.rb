class RemoveStateDataIndexFromToolStates < ActiveRecord::Migration[8.0]
  def change
    remove_index :tool_states, :state_data, if_exists: true
  end
end
