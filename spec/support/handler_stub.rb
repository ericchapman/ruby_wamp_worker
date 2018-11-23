class SubscribeHandler < Wamp::Worker::Handler
  subscribe "com.example.topic1", match: true

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  def handler
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

  def handler
    self.class.increment_run_count

    if self.kwargs[:error]
      raise Wamp::Client::CallError.new("error")
    end

    self.args[0] + 2
  end
end

class SubscribeBackgroundHandler < Wamp::Worker::BackgroundHandler
  subscribe "com.example.topic1_back", match: true

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  def handler
    self.class.increment_run_count
  end
end

class RegisterBackgroundHandler < Wamp::Worker::BackgroundHandler
  register "com.example.procedure1_back"
  register "com.example.procedure2_back", name: :other

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  def handler
    self.class.increment_run_count

    if kwargs[:error]
      raise Wamp::Client::CallError.new("error")
    end

    Wamp::Client::CallResult.new([(self.args[0] + 2)])
  end
end

