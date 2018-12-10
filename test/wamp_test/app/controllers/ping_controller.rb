class PingController < ApplicationController
  def index
    self.wamp_session.publish "com.example.back.ping", [params[:a].to_i, params[:b].to_i], {}, { exclude_me: false }

    render json: { result: true }
  end
end
