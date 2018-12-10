class AddHandler
  include Wamp::Worker::Handler

  register"com.example.add", :add, { invoke: "roundrobin" }

  def add
    args[0] + args[1]
  end
end