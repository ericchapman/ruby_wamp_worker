require "spec_helper"

class Handler1
  include Wamp::Worker::Handler

  def handler
  end
end

describe Wamp::Worker::Config do
  let(:config) { described_class.new }
  let(:proxy) { Wamp::Worker::ConfigProxy.new(config) }

  it "sets everything to the default" do
    proxy.configure do
      timeout 100
      connection option: true

      subscribe "topic", Handler1, :handler, match: true
      register "procedure", Handler1, :handler
    end

    expect(config.connection).to eq({option: true})
    expect(config.timeout).to eq(100)
    expect(config.redis.is_a?(::Redis)).to eq(true)
    expect(config.registrations.count).to eq(1)
    expect(config.subscriptions.count).to eq(1)
  end

  it "uses a namespace" do
    proxy.configure do
      timeout 100
      redis Redis.new
      connection option: true, value: false

      subscribe "topic1", Handler1, :handler
      register "procedure1", Handler1, :handler

      namespace :other do
        timeout 200
        connection option: false

        subscribe "topic2", Handler1, :handler
        register "procedure2", Handler1, :handler, prefix: true

        namespace :another do
          timeout 300

          register "procedure3", Handler1, :handler, prefix: true
        end
      end
    end

    expect(config.connection).to eq({option: true, value: false})
    expect(config.timeout).to eq(100)
    expect(config.redis.is_a?(::Redis)).to eq(true)
    expect(config.registrations.count).to eq(1)
    expect(config.subscriptions.count).to eq(1)

    expect(config.connection(:other)).to eq({option: false, value: false})
    expect(config.timeout(:other)).to eq(200)
    expect(config.redis(:other).is_a?(::Redis)).to eq(true)
    expect(config.registrations(:other).count).to eq(2)
    expect(config.subscriptions(:other).count).to eq(2)

    expect(config.connection(:another)).to eq({option: false, value: false})
    expect(config.timeout(:another)).to eq(300)
    expect(config.redis(:another).is_a?(::Redis)).to eq(true)
    expect(config.registrations(:another).count).to eq(3)
    expect(config.subscriptions(:another).count).to eq(2)
  end

  it "iterates the parents" do
    proxy.configure do
      namespace :n1 do
        namespace :n2 do
          namespace :n3 do
            namespace :n4 do
              namespace :n5 do
              end
            end
          end
        end
      end
    end

    parents = []
    config.parents :n5, :timeout do |name, value|
      parents << name
    end

    expect(parents).to eq([:default, :n1,:n2,:n3,:n4,:n5])
  end

end

