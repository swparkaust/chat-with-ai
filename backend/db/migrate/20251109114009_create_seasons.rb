class CreateSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons do |t|
      t.integer :season_number, null: false
      t.boolean :active, default: false, null: false
      t.string :first_name
      t.string :last_name
      t.string :profile_picture
      t.string :status_message
      t.datetime :start_date, null: false
      t.datetime :end_date
      t.datetime :deactivation_warned_at

      t.timestamps
    end
    add_index :seasons, :season_number, unique: true
    add_index :seasons, :active
  end
end
