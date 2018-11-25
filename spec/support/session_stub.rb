class SessionStub
  attr_reader :subscriptions, :registrations, :defers

  def initialize
    @subscriptions = {}
    @registrations = {}
    @defers = {}
  end

  def publish(topic, args=nil, kwargs=nil, options={}, &callback)
    subscription = self.subscriptions[topic]
    error = nil

    if subscription
      subscription.call(args, kwargs, {})
    else
      error = "no subscriber found"
    end

    if callback and options[:acknowledge]
      callback.call(1234, error, { topic: topic })
    end
  end

  def call(procedure, args=nil, kwargs=nil, options={}, &callback)
    registration = self.registrations[procedure]
    request = SecureRandom.uuid
    result = nil
    error = nil

    if registration
      begin
        result = registration.call(args, kwargs, {request: request})
      rescue Exception => e
        if e.is_a? Wamp::Client::CallError
          result = e
        else
          result = Wamp::Client::CallError.new("error")
        end
      end

      if result.nil?
        result = Wamp::Client::CallResult.new
      elsif result.is_a?(Wamp::Client::Defer::CallDefer)
        # Do nothing
      elsif result.is_a?(Wamp::Client::CallError)
        error = result.error
        result = nil
      elsif not result.is_a?(Wamp::Client::CallResult)
        result = Wamp::Client::CallResult.new([result])
      end
    else
      error = "no registration found"
    end

    if callback
      if result.is_a?(Wamp::Client::Defer::CallDefer)
        self.defers[request] = callback
      elsif result
        callback.call({args: result.args, kwargs: result.kwargs}, error, { procedure: procedure })
      else
        callback.call(nil, error, { procedure: procedure })
      end
    end
  end

  def register(procedure, handler, options=nil, interrupt=nil, &callback)
    self.registrations[procedure] = handler

    if callback
      callback.call({procedure: procedure, handler: handler}, nil, nil)
    end
  end

  def subscribe(topic, handler, options={}, &callback)
    self.subscriptions[topic] = handler

    if callback
      callback.call({topic: topic, handler: handler}, nil, nil)
    end
  end

  def yield(request, result, options={}, check_defer=false)
    callback = self.defers.delete(request)
    if callback
      if result.nil?
        result = Wamp::Client::CallResult.new
      elsif result.is_a?(Wamp::Client::CallError)
        # Do nothing
      elsif not result.is_a?(Wamp::Client::CallResult)
        result = Wamp::Client::CallResult.new([result])
      end

      if result.is_a?(Wamp::Client::CallError)
        callback.call(nil, result.error, { request: request })
      else
        callback.call({ args: result.args, kwargs: result.kwargs }, nil, { request: request })
      end
    end

  end

end