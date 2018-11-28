require "spec_helper"

describe Wamp::Worker::Queue do
  let(:name) { :default }
  let(:queue) { described_class.new(name) }
  let(:queue_name) { "test:command" }
  let(:handle) { "test:response" }
  let(:params) { { temp: true } }

  it "general push/pop" do
    # Push the request
    queue.push queue_name, :call, params, handle

    # Pop the request
    descriptor = queue.pop(queue_name, wait: true)
    expect(descriptor.command).to eq(:call)
    expect(descriptor.handle).to eq(handle)
    expect(descriptor.params).to eq(params)

    # Check and make sure the key still exists
    expect(queue.redis.exists(queue_name)).to eq(true)
  end

  it "deletes on pop" do
    expect(queue.redis.exists(queue_name)).to eq(false)

    # Push the request
    queue.push queue_name, :call, params, handle

    expect(queue.redis.exists(queue_name)).to eq(true)

    # Pop the request
    descriptor = queue.pop(queue_name, delete: true)
    expect(descriptor.command).to eq(:call)
    expect(descriptor.handle).to eq(handle)
    expect(descriptor.params).to eq(params)

    expect(queue.redis.exists(queue_name)).to eq(false)
  end

end
