class BackPingHandler
  include Wamp::Worker::BackgroundHandler

  subscribe "com.example.back.ping", :ping

  def ping
    self.session.publish "com.example.back.pong", self.args, self.kwargs
  end

end
