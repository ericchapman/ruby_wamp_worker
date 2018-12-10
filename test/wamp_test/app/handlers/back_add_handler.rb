class BackAddHandler
  include Wamp::Worker::BackgroundHandler

  register"com.example.back.add", :add, { invoke: "roundrobin" }

  def add
    args[0] + args[1]
  end
end
