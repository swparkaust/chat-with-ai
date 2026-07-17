class CreateToolStates < ActiveRecord::Migration[8.0]
  def change
    create_table :tool_states do |t|
      t.references :season, null: false, foreign_key: true
      t.string :tool_name, null: false
      t.jsonb :state_data, null: false, default: {}

      t.timestamps
    end
    add_index :tool_states, [:season_id, :tool_name], unique: true
    add_index :tool_states, :state_data, using: :gin
  end
end
