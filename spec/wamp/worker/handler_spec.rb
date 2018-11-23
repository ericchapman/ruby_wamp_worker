require "spec_helper"

class Handler1 < Wamp::Worker::Handler
  subscribe "com.example.topic1", match: true
end

class Handler2 < Wamp::Worker::Handler
  register "com.example.procedure1"
  register "com.example.procedure2", name: :other

  def invoke
    self.args[0] + 2
  end
end

describe Wamp::Worker::Handler do

  it "registers the handlers" do

    # Globally subscribe
    Wamp::Worker.configure do
      namespace :other do
        subscribe "com.example.topic2", Handler1
      end
    end

    config = Wamp::Worker.config

    expect(config.subscriptions.count).to eq(1)
    expect(config.subscriptions(:other).count).to eq(2)

    subscriptions = config.subscriptions(:other)

    subscription = subscriptions[0]
    expect(subscription.klass).to eq(Handler1)
    expect(subscription.topic).to eq("com.example.topic1")
    expect(subscription.options).to eq({match: true})

    subscription = subscriptions[1]
    expect(subscription.klass).to eq(Handler1)
    expect(subscription.topic).to eq("com.example.topic2")

    expect(config.registrations.count).to eq(1)
    expect(config.registrations(:other).count).to eq(2)

    registrations = config.registrations(:other)

    registration = registrations[0]
    expect(registration.klass).to eq(Handler2)
    expect(registration.procedure).to eq("com.example.procedure1")

    registration = registrations[1]
    expect(registration.klass).to eq(Handler2)
    expect(registration.procedure).to eq("com.example.procedure2")
  end

end

