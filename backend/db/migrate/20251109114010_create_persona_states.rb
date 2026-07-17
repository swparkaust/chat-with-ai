class CreatePersonaStates < ActiveRecord::Migration[8.0]
  def change
    create_table :persona_states do |t|
      t.references :season, null: false, foreign_key: true
      t.jsonb :state_data, null: false, default: {}

      t.timestamps
    end
    add_index :persona_states, :state_data, using: :gin
  end
end
