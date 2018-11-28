require "spec_helper"

describe Wamp::Worker::Proxy::Requestor do
  let(:name) { :default }
  let(:topic) { "topic" }
  let(:procedure) { "procedure" }
  let(:handle) { "handle" }
  let(:requestor) { described_class.new(name) }

  context "wait" do
    before(:each) {
      allow_any_instance_of(described_class).to receive(:unique_command_resp_queue).and_return(handle)
    }

    it "publishes with acknowledge" do
      # Need to place the response in the handle queue first
      requestor.queue.push handle, :publish, { result: { args: [2] } }

      # Make the call
      requestor.publish(topic, [1], {}, { acknowledge: true }) do |result, error, details|
        expect(result[:args][0]).to eq(2)
      end

      # Make sure the request is in the queue
      descriptor = requestor.queue.pop requestor.command_req_queue
      expect(descriptor.command).to eq(:publish)
      expect(descriptor.params).to eq({:topic=>topic, :args=>[1], :kwargs=>{}, :options=>{:acknowledge=>true}})
      expect(descriptor.handle).to eq(handle)
    end

    it "calls a procedure" do
      # Need to place the response in the handle queue first
      requestor.queue.push handle, :call, { result: { args: [3] } }

      # Make the call
      requestor.call(procedure, [2], {}) do |result, error, details|
        expect(result[:args][0]).to eq(3)
      end

      # Make sure the request is in the queue
      descriptor = requestor.queue.pop requestor.command_req_queue
      expect(descriptor.command).to eq(:call)
      expect(descriptor.params).to eq({:procedure=>procedure, :args=>[2], :kwargs=>{}, :options=>{}})
      expect(descriptor.handle).to eq(handle)
    end

    it "has an unresponsive worker" do
      # Create the response
      allow_any_instance_of(RedisStub).to receive(:brpop) do |redis, key, **args|
        nil
      end

      # Make the call
      expect {
        requestor.call(procedure, [2], {})
      }.to raise_error(Wamp::Worker::Error::WorkerNotResponding)
    end

    it "has no response" do
      # Create the response
      allow_any_instance_of(RedisStub).to receive(:brpop) do |redis, key, **args|
        requestor.ticker.increment(requestor.ticker_key)
        nil
      end

      # Make the call
      expect {
        requestor.call(procedure, [2], {})
      }.to raise_error(Wamp::Worker::Error::ResponseTimeout)
    end
  end

  it "does the publish but doesn't wait" do
    # Make the call
    requestor.publish(topic, [1], {}) do |result, error, details|
      expect(result[:args][0]).to eq(2)
    end

    # Make sure the request is in the queue
    descriptor = requestor.queue.pop requestor.command_req_queue
    expect(descriptor.command).to eq(:publish)
    expect(descriptor.params).to eq({:topic=>topic, :args=>[1], :kwargs=>{}, :options=>{}})
    expect(descriptor.handle.start_with?("wamp:default:response")).to eq(true)
  end
end

