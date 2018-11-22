class SessionStub
  attr_reader :subscriptions, :registrations

  def initialize
    @subscriptions = {}
    @registrations = {}
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
    result = nil
    error = nil

    if registration
      result = registration.call(args, kwargs, {})
    else
      error = "no registration found"
    end

    if callback
      callback.call(result, error, { procedure: procedure })
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


end