class BackAddHandler
  include Wamp::Worker::BackgroundHandler

  register"com.example.back.add", :add, { invoke: "roundrobin" }
  register"com.example.back.add.delay", :add_delay, { invoke: "roundrobin" }

  def add
    args[0] + args[1]
  end

  def add_delay
    progress 0.0
    sleep 0.1

    progress 0.25
    sleep 0.1

    progress 0.5
    sleep 0.1

    progress 0.75
    sleep 0.1

    args[0] + args[1]
  end
end
