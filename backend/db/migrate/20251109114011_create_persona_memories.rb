class CreatePersonaMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :persona_memories do |t|
      t.references :season, null: false, foreign_key: true
      t.text :content, null: false
      t.float :significance, null: false, default: 5.0
      t.float :emotional_intensity, null: false, default: 5.0
      t.float :detail_level, null: false, default: 1.0
      t.integer :recall_count, null: false, default: 0
      t.datetime :last_recalled_at
      t.datetime :memory_timestamp, null: false
      t.string :tags, array: true, default: []

      t.timestamps
    end
    add_index :persona_memories, :tags, using: :gin
    add_index :persona_memories, :significance
  end
end
