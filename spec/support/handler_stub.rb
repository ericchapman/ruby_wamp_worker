class Handler

  def topic
    self.class.increment_run_count
  end

  def return_error
    self.class.increment_run_count
    Wamp::Client::Response::CallError.new("error")
  end

  def throw_error
    self.class.increment_run_count
    raise Wamp::Client::Response::CallError.new("error")
  end

  def throw_exception
    self.class.increment_run_count
    raise StandardError.new("error")
  end

  def call_result
    self.class.increment_run_count
    Wamp::Client::Response::CallResult.new([(self.args[0] + 2)])
  end

  def normal_result
    self.class.increment_run_count
    self.args[0] + 3
  end

  def nil_result
    self.class.increment_run_count
    nil
  end

  def proxy_result
    self.class.increment_run_count
    response = nil
    self.session.call("normal_result", self.args, self.kwargs) do |result, error, details|
      response = result[:args][0]
    end
    response
  end

  def progress_result
    self.class.increment_run_count
    self.progress(0)
    self.progress(0.5)
    self.progress(1.0)
    self.args[0] + 4
  end

end


class NormalHandler < Handler
  include Wamp::Worker::Handler

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  subscribe "topic", :topic
  subscribe "other.topic", :topic, :name => :other
  register "return_error", :return_error
  register "throw_error", :throw_error
  register "throw_exception", :throw_exception
  register "call_result", :call_result
  register "other.call_result", :call_result, :name => :other
  register "normal_result", :normal_result
  register "nil_result", :nil_result
  register "proxy_result", :proxy_result
  register "progress_result", :progress_result
end

class BackgroundHandler < Handler
  include Wamp::Worker::BackgroundHandler

  @@run_count = 0
  def self.increment_run_count
    @@run_count += 1
  end
  def self.run_count
    @@run_count
  end

  subscribe "back.topic", :topic
  subscribe "back.other.topic", :topic, :name => :other
  register "back.return_error", :return_error
  register "back.throw_error", :throw_error
  register "back.throw_exception", :throw_exception
  register "back.call_result", :call_result
  register "back.other.call_result", :call_result, :name => :other
  register "back.normal_result", :normal_result
  register "back.nil_result", :nil_result
  register "back.proxy_result", :proxy_result
  register "back.progress_result", :progress_result
end


