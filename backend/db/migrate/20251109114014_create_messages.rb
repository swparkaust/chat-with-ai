class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :sender_type, null: false
      t.text :content, null: false
      t.datetime :read_at
      t.boolean :is_fragment, default: false
      t.integer :fragment_index

      t.timestamps
    end
    add_index :messages, :sender_type
    add_index :messages, :read_at
    add_index :messages, :created_at
  end
end
