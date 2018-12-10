class AddController < ApplicationController
  def index
    response = nil

    self.wamp_session.call "com.example.back.add", [params[:a].to_i, params[:b].to_i] do |result, error, details|
      response = result
    end

    render json: { result: response }
  end
end