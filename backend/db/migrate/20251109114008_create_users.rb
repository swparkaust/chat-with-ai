class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :device_id, null: false
      t.string :name
      t.string :status_message
      t.string :profile_picture
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :users, :device_id, unique: true
    add_index :users, :last_seen_at
  end
end
