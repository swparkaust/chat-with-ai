class CreateUserStates < ActiveRecord::Migration[8.0]
  def change
    create_table :user_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.datetime :typing_at
      t.datetime :last_seen_at
      t.boolean :is_focused, default: false
      t.integer :scroll_position, default: 0

      t.timestamps
    end
    add_index :user_states, [:user_id, :conversation_id], unique: true
  end
end
