module SeasonJsonHelper
  extend ActiveSupport::Concern

  private

  def season_json(season)
    season.as_json(only: [:id, :season_number, :first_name, :last_name, :status_message, :active, :start_date, :end_date]).merge(
      full_name: season.full_name,
      profile_picture: season.profile_picture.attached? ? url_for(season.profile_picture) : nil
    )
  end
end
