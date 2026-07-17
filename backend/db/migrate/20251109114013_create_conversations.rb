class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.datetime :last_message_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :conversations, [:user_id, :season_id], unique: true
    add_index :conversations, :last_message_at
    add_index :conversations, :active
  end
end
