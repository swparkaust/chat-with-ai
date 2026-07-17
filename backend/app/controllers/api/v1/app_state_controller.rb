module Api
  module V1
    class AppStateController < ApplicationController
      def show
        render json: { app_state: AppStateSerializer.build }
      end
    end
  end
end
