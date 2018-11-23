require "spec_helper"

describe Wamp::Worker::Handler do

  it "registers the handlers" do

    # Globally subscribe
    Wamp::Worker.configure do
      namespace :other do
        subscribe "com.example.topic2", SubscribeHandler
      end
    end

    config = Wamp::Worker.config

    expect(config.subscriptions.count).to eq(1)
    expect(config.subscriptions(:other).count).to eq(2)

    subscriptions = config.subscriptions(:other)

    subscription = subscriptions[0]
    expect(subscription.klass).to eq(SubscribeHandler)
    expect(subscription.topic).to eq("com.example.topic1")
    expect(subscription.options).to eq({match: true})

    subscription = subscriptions[1]
    expect(subscription.klass).to eq(SubscribeHandler)
    expect(subscription.topic).to eq("com.example.topic2")

    expect(config.registrations.count).to eq(1)
    expect(config.registrations(:other).count).to eq(2)

    registrations = config.registrations(:other)

    registration = registrations[0]
    expect(registration.klass).to eq(RegisterHandler)
    expect(registration.procedure).to eq("com.example.procedure1")

    registration = registrations[1]
    expect(registration.klass).to eq(RegisterHandler)
    expect(registration.procedure).to eq("com.example.procedure2")
  end

end

