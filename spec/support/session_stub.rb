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
      error = { error: "no subscriber found", args:[], kwargs:{} }
    end

    if callback and options[:acknowledge]
      callback.call(1234, error, { topic: topic })
    end
  end

  def call(procedure, args=nil, kwargs=nil, options={}, &callback)
    registration = self.registrations[procedure]
    request = SecureRandom.uuid

    if registration

      # Perform the API call
      begin
        result = registration.call(args, kwargs, {request: request})
      rescue Wamp::Client::CallError => e
        result = e
      rescue StandardError
        result = Wamp::Client::CallError.new("error")
      end

      # Parse the response
      unless result.is_a?(Wamp::Client::Defer::CallDefer)
        response = Wamp::Worker::Proxy::Response.from_result(result)&.to_hash || {}
        result = response[:result]
        error = response[:error]
      end
    else
      result = nil
      error = { error: "no registration found", args:[], kwargs:{} }
    end

    if callback
      if result.is_a?(Wamp::Client::Defer::CallDefer)
        self.defers[request] = callback
      else
        callback.call(result, error, { procedure: procedure })
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
      response = Wamp::Worker::Proxy::Response.from_result(result)&.to_hash || {}
      callback.call(response[:result], response[:error], { request: request })
    end

  end

end