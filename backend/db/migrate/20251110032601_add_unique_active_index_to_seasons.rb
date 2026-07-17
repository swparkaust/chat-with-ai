class AddUniqueActiveIndexToSeasons < ActiveRecord::Migration[8.0]
  def change
    # Add a partial unique index to ensure only one active season exists at a time
    # The "where" clause makes this a partial index that only applies when active = true
    add_index :seasons, :active, unique: true, where: "active = true", name: "index_seasons_on_active_unique"
  end
end
