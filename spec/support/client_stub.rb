class ClientStub
  attr_accessor :session, :options, :is_open

  def transport_class
    Wamp::Client::Transport::Base
  end

  def initialize(options)
    self.options = options
    self.is_open = false
    self.session = SessionStub.new
    @callbacks = {}
  end

  def open
    self.is_open = true

    # Fake connect
    trigger(:connect) { |handler| handler.call }

    # Fake challenge
    trigger(:challenge) { |handler| handler.call('wampcra', {}) } if self.options[:should_challenge]

    # Fake join
    trigger(:join) { |handler| handler.call(self.session, {}) }
  end

  def close
    # Fake leave
    trigger(:leave) { |handler| handler.call('left', {}) }

    # Fake disconnect
    trigger(:disconnect) { |handler| handler.call('left') }

    self.is_open = false
  end

  def on(event, &callback)
    @callbacks[event] = callback
  end

  def trigger(event, &callback)
    handler = @callbacks[event]
    callback.call(handler) if handler
  end

end