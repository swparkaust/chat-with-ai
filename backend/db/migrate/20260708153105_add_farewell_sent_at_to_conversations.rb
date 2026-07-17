class AddFarewellSentAtToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :farewell_sent_at, :datetime
  end
end
