require "spec_helper"

describe Wamp::Worker::Proxy do
  let(:redis) { RedisStub.new }
  let(:name) { :default }

  let(:requestor) { described_class::Requestor.new(redis, name) }
  let(:dispatcher) { described_class::Dispatcher.new(redis, name, SessionStub.new) }

  context "requestor" do

    it "sends a call command and processes the response" do
      response = { result: 2 }
      allow_any_instance_of(RedisStub).to receive(:lpush) do |object, key, descriptor_string|
        # Parse the descriptor and push a response
        descriptor = Wamp::Worker::Redis::Descriptor.from_json descriptor_string
        dispatcher.queue.push_response(descriptor.command, descriptor.handle, response)

        # Check the call parameters in the descriptor
        expected = {:procedure=>"procedure", :args=>[1], :kwargs=>nil, :options=>{}}
        expect(descriptor.params).to eq(expected)
      end

      requestor.call("procedure", [1]) do |result, error, detail|
        expect(result).to eq(2)
      end
    end

    it "sends a publish command and processes the response" do
      response = { result: 2 }
      allow_any_instance_of(RedisStub).to receive(:lpush) do |object, key, descriptor_string|
        # Parse the descriptor and push a response
        descriptor = Wamp::Worker::Redis::Descriptor.from_json descriptor_string
        dispatcher.queue.push_response(descriptor.command, descriptor.handle, response)

        # Check the call parameters in the descriptor
        expected = {:topic=>"topic", :args=>[1], :kwargs=>nil, :options=>{}}
        expect(descriptor.params).to eq(expected)
      end

      requestor.publish("topic", [1]) do |result, error, detail|
        expect(result).to eq(2)
      end
    end
  end

  context "dispatcher" do

    it "parses publish command with acknowledge (should wait)" do
      handle = requestor.queue.push_request :publish, { topic:"topic", args:[1], kwargs:nil, options:{acknowledge: true}}

      dispatcher.process_requests

      descriptor = requestor.queue.pop_response(handle)

      expect(descriptor.command).to eq(:publish)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:details][:topic]).to eq("topic")
    end

    it "parses publish command without acknowledge (should not respond)" do
      handle = requestor.queue.push_request :publish, { topic:"topic", args:[1], kwargs:nil, options:{}}

      dispatcher.process_requests

      expect {
        requestor.queue.pop_response(handle)
      }.to raise_error(Wamp::Worker::Redis::WorkerNotResponding)
    end

    it "parses call command" do
      handle = requestor.queue.push_request :call, { procedure:"procedure", args:[1], kwargs:nil, options:{} }

      dispatcher.process_requests

      descriptor = requestor.queue.pop_response(handle)

      expect(descriptor.command).to eq(:call)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:details][:procedure]).to eq("procedure")
    end

    it "parses multiple commands" do
      handle1 = requestor.queue.push_request :call, { procedure:"procedure", args:[1], kwargs:nil, options:{} }
      handle2 = requestor.queue.push_request :publish, { topic:"topic", args:[1], kwargs:nil, options:{acknowledge:true} }

      dispatcher.process_requests

      descriptor = requestor.queue.pop_response(handle1)

      expect(descriptor.command).to eq(:call)
      expect(descriptor.handle).to eq(handle1)
      expect(descriptor.params[:details][:procedure]).to eq("procedure")

      descriptor = requestor.queue.pop_response(handle2)

      expect(descriptor.command).to eq(:publish)
      expect(descriptor.handle).to eq(handle2)
      expect(descriptor.params[:details][:topic]).to eq("topic")
    end

    it "errors on invalid method" do
      handle = requestor.queue.push_request :bad, {procedure: "procedure", args:[1], kwargs:nil, options:{} }

      dispatcher.process_requests

      descriptor = requestor.queue.pop_response(handle)

      expect(descriptor.command).to eq(:bad)
      expect(descriptor.handle).to eq(handle)
      expect(descriptor.params[:error][:error]).to eq("unsupported proxy command 'bad'")
    end

    it "increments the tick" do
      dispatcher.process_requests
      expect{
        dispatcher.process_requests
      }.to change{ redis.get(dispatcher.queue.get_tick_key) }.by(1)
    end
  end
end

