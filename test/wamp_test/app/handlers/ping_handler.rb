class PingHandler
  include Wamp::Worker::Handler

  subscribe "com.example.ping", :ping

  def ping
    self.session.publish "com.example.pong", self.args, self.kwargs
  end

end