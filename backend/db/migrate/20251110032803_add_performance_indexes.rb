class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite index for unread message queries
    # Speeds up queries like: messages.where(conversation_id: X, sender_type: 'ai', read_at: nil)
    add_index :messages, [:conversation_id, :sender_type, :read_at],
              name: "index_messages_on_conversation_sender_read"

    # Index for conversations by season and active status
    # Speeds up queries like: conversations.where(season_id: X, active: true)
    add_index :conversations, [:season_id, :active],
              name: "index_conversations_on_season_active"

    # Index for messages by created_at for pagination and ordering
    # Speeds up queries like: messages.order(created_at: :asc)
    add_index :messages, [:conversation_id, :created_at],
              name: "index_messages_on_conversation_created"
  end
end
