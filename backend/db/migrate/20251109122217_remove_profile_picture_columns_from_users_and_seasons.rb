class RemoveProfilePictureColumnsFromUsersAndSeasons < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :profile_picture, :string
    remove_column :seasons, :profile_picture, :string
  end
end
