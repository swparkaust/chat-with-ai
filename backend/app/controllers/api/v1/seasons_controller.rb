module Api
  module V1
    class SeasonsController < ApplicationController
      include SeasonJsonHelper

      def current
        season = Season.current

        if season
          render json: {
            season: season_json(season)
          }
        else
          render json: { error: 'No active season' }, status: :not_found
        end
      end

      def show
        season = Season.find(params[:id])

        render json: {
          season: season_json(season)
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Season not found' }, status: :not_found
      end

      def index
        seasons = Season.ordered.limit(10)

        render json: {
          seasons: seasons.map { |s| season_json(s) }
        }
      end
    end
  end
end
