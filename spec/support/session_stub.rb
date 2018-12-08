class SessionStub
  attr_reader :subscriptions, :registrations, :defers, :calls

  def initialize
    @subscriptions = {}
    @registrations = {}
    @defers = {}
    @calls = {}
  end

  def publish(topic, args=nil, kwargs=nil, options={}, &callback)
    subscription = self.subscriptions[topic]
    error = nil

    if subscription
      subscription.call(args, kwargs, {})
    else
      error = Wamp::Client::Response::CallError.new("wamp.no_subscriber").to_hash
    end

    if callback and options[:acknowledge]
      callback.call(1234, error, { topic: topic })
    end
  end

  def call(procedure, args=nil, kwargs=nil, options={}, &callback)
    registration = self.registrations[procedure]
    request = SecureRandom.uuid

    self.calls[request] = callback

    if registration
      details = options.clone
      details[:request] = request

      result = Wamp::Client::Response.invoke_handler do
        registration.call(args, kwargs, details)
      end
    else
      result = Wamp::Client::Response::CallError.new("wamp.no_procedure")
    end

    if callback
      if result.is_a?(Wamp::Client::Response::CallDefer)
        self.defers[request] = callback
      else
        self.yield(request, result, options)
      end
    end

    self.calls.delete(request)
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

    # Get the callback
    callback =
        if check_defer
          callback = self.defers[request]
          self.defers.delete(request) unless options[:progress]
          callback
        else
          self.calls[request]
        end

    # If there is a callback, handle it
    if callback

      # Create the response object
      result = Wamp::Client::Response::CallResult.ensure(result, allow_error: true)

      # Create the details
      details = { request: request, progress: options[:progress] }

      # Call the callback
      if result.is_a?(Wamp::Client::Response::CallError)
        callback.call(nil, result.to_hash, details)
      else
        callback.call(result.to_hash, nil, details)
      end
    end

  end

end