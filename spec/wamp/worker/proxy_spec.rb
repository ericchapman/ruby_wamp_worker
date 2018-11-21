require "spec_helper"

describe Wamp::Worker::Proxy do
  let(:redis) { RedisStub.new }
  let(:name) { :default }

  let(:requestor) { Wamp::Worker::Redis::Requestor.new(redis, name) }
  let(:dispatcher) { Wamp::Worker::Redis::Dispatcher.new(redis, name) }

  context "session" do
    let(:session) { described_class::Session.new(requestor) }

    it "sends a call command and processes the response" do
      response = { result: 2 }
      allow_any_instance_of(RedisStub).to receive(:lpush) do |object, key, descriptor_string|
        # Parse the descriptor and push a response
        descriptor = Wamp::Worker::Redis::Descriptor.from_json descriptor_string
        dispatcher.push_response(descriptor.command, descriptor.handle, response)

        # Check the call parameters in the descriptor
        expected = {:procedure=>"procedure", :args=>[1], :kwargs=>nil, :options=>{}}
        expect(descriptor.params).to eq(expected)
      end

      session.call("procedure", [1]) do |result, error, detail|
        expect(result).to eq(2)
      end
    end

    it "sends a publish command and processes the response" do
      response = { result: 2 }
      allow_any_instance_of(RedisStub).to receive(:lpush) do |object, key, descriptor_string|
        # Parse the descriptor and push a response
        descriptor = Wamp::Worker::Redis::Descriptor.from_json descriptor_string
        dispatcher.push_response(descriptor.command, descriptor.handle, response)

        # Check the call parameters in the descriptor
        expected = {:topic=>"topic", :args=>[1], :kwargs=>nil, :options=>{}}
        expect(descriptor.params).to eq(expected)
      end

      session.publish("topic", [1]) do |result, error, detail|
        expect(result).to eq(2)
      end
    end
  end

  context "worker" do
    let(:worker) { described_class::Worker.new(dispatcher, SessionStub.new) }

    it "parses publish command" do
      handle = requestor.push_request :publish, {:topic=>"topic", :args=>[1], :kwargs=>nil, :options=>{}}

      worker.process_requests

      descriptor = requestor.pop_response(handle)

      expect(descriptor.command).to eq(:publish)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:result][:topic]).to eq("topic")
    end

    it "parses call command" do
      handle = requestor.push_request :call, {:procedure=>"procedure", :args=>[1], :kwargs=>nil, :options=>{}}

      worker.process_requests

      descriptor = requestor.pop_response(handle)

      expect(descriptor.command).to eq(:call)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:result][:procedure]).to eq("procedure")
    end

    it "parses multiple commands" do
      handle1 = requestor.push_request :call, {:procedure=>"procedure", :args=>[1], :kwargs=>nil, :options=>{}}
      handle2 = requestor.push_request :publish, {:topic=>"topic", :args=>[1], :kwargs=>nil, :options=>{}}

      worker.process_requests

      descriptor = requestor.pop_response(handle1)

      expect(descriptor.command).to eq(:call)
      expect(descriptor.handle).to eq(handle1)
      expect(descriptor.params[:result][:procedure]).to eq("procedure")

      descriptor = requestor.pop_response(handle2)

      expect(descriptor.command).to eq(:publish)
      expect(descriptor.handle).to eq(handle2)
      expect(descriptor.params[:result][:topic]).to eq("topic")
    end

    it "errors on invalid method" do
      handle = requestor.push_request :bad, {:procedure=>"procedure", :args=>[1], :kwargs=>nil, :options=>{}}

      worker.process_requests

      descriptor = requestor.pop_response(handle)

      expect(descriptor.command).to eq(:bad)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:error][:error]).to eq("unsupported proxy command 'bad'")
    end

    it "increments the tick" do
      worker.process_requests
      expect{
        worker.process_requests
      }.to change{ redis.get(dispatcher.get_tick_key) }.by(1)
    end
  end
end

