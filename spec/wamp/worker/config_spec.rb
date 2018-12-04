require "spec_helper"

class Handler1
  include Wamp::Worker::Handler

  def handler
  end
end

describe Wamp::Worker::Config do
  let(:config) { described_class.new }
  let(:proxy) { Wamp::Worker::ConfigProxy.new(config) }
  let(:other_proxy) { Wamp::Worker::ConfigProxy.new(config, :other) }

  it "sets everything to the default" do
    proxy.configure do
      timeout 100
      connection option: true

      subscribe "topic", Handler1, :handler, match: true
      register "procedure", Handler1, :handler
    end

    expect(config.connection).to eq({option: true})
    expect(config.timeout).to eq(100)
    expect(config.redis.is_a?(RedisStub)).to eq(true)
    expect(config.registrations.count).to eq(1)
    expect(config.subscriptions.count).to eq(1)

    expect(config.connection(:default)).to eq({option: true})
    expect(config.timeout(:default)).to eq(100)
    expect(config.redis(:default).is_a?(RedisStub)).to eq(true)
    expect(config.registrations(:default).count).to eq(1)
    expect(config.subscriptions(:default).count).to eq(1)
  end

  it "sets everything to other" do
    other_proxy.configure do
      timeout 100
      connection option: true

      subscribe "topic", Handler1, :handler, match: true
      register "procedure", Handler1, :handler
    end

    # Defaults
    expect(config.connection).to eq({})
    expect(config.timeout).to eq(60)
    expect(config.redis.is_a?(RedisStub)).to eq(true)
    expect(config.registrations.count).to eq(0)
    expect(config.subscriptions.count).to eq(0)

    expect(config.connection(:other)).to eq({option: true})
    expect(config.timeout(:other)).to eq(100)
    expect(config.redis(:other).is_a?(RedisStub)).to eq(true)
    expect(config.registrations(:other).count).to eq(1)
    expect(config.subscriptions(:other).count).to eq(1)
  end

  it "does both" do
    proxy.configure do
      timeout 100
      connection option: true

      subscribe "topic", Handler1, :handler, match: true
      register "procedure", Handler1, :handler
    end

    other_proxy.configure do
      timeout 110
      connection option: false

      subscribe "topic", Handler1, :handler, match: true
      register "procedure", Handler1, :handler
    end

    expect(config.connection).to eq({option: true})
    expect(config.timeout).to eq(100)
    expect(config.redis.is_a?(RedisStub)).to eq(true)
    expect(config.registrations.count).to eq(1)
    expect(config.subscriptions.count).to eq(1)

    expect(config.connection(:other)).to eq({option: false})
    expect(config.timeout(:other)).to eq(110)
    expect(config.redis(:other).is_a?(RedisStub)).to eq(true)
    expect(config.registrations(:other).count).to eq(1)
    expect(config.subscriptions(:other).count).to eq(1)
  end
end

