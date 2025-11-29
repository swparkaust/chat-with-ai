class AddIndexForUserInterruptDetection < ActiveRecord::Migration[8.0]
  def change
    # Add composite index for efficient user interrupt detection query
    # Covers: WHERE conversation_id = ? AND sender_type = 'user' AND created_at > ?
    add_index :messages, [:conversation_id, :sender_type, :created_at],
              name: 'index_messages_on_conversation_sender_created',
              if_not_exists: true
  end
end
