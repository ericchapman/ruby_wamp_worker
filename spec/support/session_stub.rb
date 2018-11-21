class SessionStub

  def publish(topic, args=nil, kwargs=nil, options={}, &callback)
    if callback
      callback.call({topic: topic, args: args, kwargs: kwargs}, nil, nil)
    end
  end

  def call(procedure, args=nil, kwargs=nil, options={}, &callback)
    if callback
      callback.call({procedure: procedure, args: args, kwargs: kwargs}, nil, nil)
    end
  end

end