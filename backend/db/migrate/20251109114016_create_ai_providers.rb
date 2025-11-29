class CreateAiProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_providers do |t|
      t.string :name, null: false
      t.string :provider_type, null: false
      t.text :api_key_encrypted
      t.jsonb :config, default: {}
      t.boolean :active, default: false

      t.timestamps
    end
    add_index :ai_providers, :provider_type
    add_index :ai_providers, :active
  end
end
