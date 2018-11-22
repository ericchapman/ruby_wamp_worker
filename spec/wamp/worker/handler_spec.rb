require "spec_helper"

class Handler1 < Wamp::Worker::Handler
  subscribe "com.example.topic1", match: true
end

class Handler2 < Wamp::Worker::Handler
  register "com.example.procedure1"
  register "com.example.procedure2"

  def invoke
    self.args[0] + 2
  end
end

describe Wamp::Worker::Handler do

  it "registers the handlers" do
    Wamp::Worker.setup do |config|
      config.routes do
        subscribe "com.example.topic2", Handler1
      end
    end

    expect(described_class.subscriptions.count).to eq(2)

    subscription = described_class.subscriptions[0]
    expect(subscription.klass).to eq(Handler1)
    expect(subscription.topic).to eq("com.example.topic1")
    expect(subscription.options).to eq({match: true})

    subscription = described_class.subscriptions[1]
    expect(subscription.klass).to eq(Handler1)
    expect(subscription.topic).to eq("com.example.topic2")

    expect(described_class.registrations.count).to eq(2)

    registration = described_class.registrations[0]
    expect(registration.klass).to eq(Handler2)
    expect(registration.procedure).to eq("com.example.procedure1")

    registration = described_class.registrations[1]
    expect(registration.klass).to eq(Handler2)
    expect(registration.procedure).to eq("com.example.procedure2")
  end

end

