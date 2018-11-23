class SubscribeHandler < Wamp::Worker::Handler
  subscribe "com.example.topic1", match: true

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  def invoke
    self.class.increment_run_count
  end
end

class RegisterHandler < Wamp::Worker::Handler
  register "com.example.procedure1"
  register "com.example.procedure2", name: :other

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  def invoke
    self.class.increment_run_count
    self.args[0] + 2
  end
end

