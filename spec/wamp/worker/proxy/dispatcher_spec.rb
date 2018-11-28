require "spec_helper"

describe Wamp::Worker::Proxy::Dispatcher do
  let(:name) { :default }
  let(:topic) { "topic" }
  let(:procedure) { "procedure" }
  let(:handle) { "handle" }
  let(:dispatcher) { described_class.new(name, SessionStub.new) }

  it "increments the ticker" do
    start_ticker = dispatcher.ticker.get(dispatcher.ticker_key)

    dispatcher.check_requests

    new_ticker = dispatcher.ticker.get(dispatcher.ticker_key)

    expect(new_ticker).to eq(start_ticker+1)
  end

  context "responses" do
    it "call" do
      allow_any_instance_of(SessionStub).to receive(:call) do |session, proc, args=nil, kwargs=nil, options={}, &callback|
        expect(procedure).to eq(proc)
        expect(args).to eq([2])
        expect(kwargs).to be_nil
        expect(options).to be_nil

        callback.call({ args: [5]}, nil, {})
      end

      dispatcher.queue.push dispatcher.command_req_queue, :call, { procedure: procedure, args:[2]}, handle

      dispatcher.check_requests

      descriptor = dispatcher.queue.pop handle
      expect(descriptor.command).to eq(:call)
      expect(descriptor.params).to eq({:result=>{:args=>[5]}, :error=>nil, :details=>{}})
      expect(descriptor.handle).to be_nil
    end

    it "publish" do
      allow_any_instance_of(SessionStub).to receive(:publish) do |session, top, args=nil, kwargs=nil, options={}, &callback|
        expect(topic).to eq(top)
        expect(args).to eq([3])
        expect(kwargs).to be_nil
        expect(options).to be_nil

        callback.call({ args: [6]}, nil, {})
      end

      dispatcher.queue.push dispatcher.command_req_queue, :publish, { topic: topic, args:[3]}, handle

      dispatcher.check_requests

      descriptor = dispatcher.queue.pop handle
      expect(descriptor.command).to eq(:publish)
      expect(descriptor.params).to eq({:result=>{:args=>[6]}, :error=>nil, :details=>{}})
      expect(descriptor.handle).to be_nil
    end

    context "yield" do
      def stub_yield
        allow_any_instance_of(SessionStub).to receive(:yield) do |session, req, args=nil, kwargs=nil, options={}, &callback|
          expect(topic).to eq(top)
          expect(args).to eq([3])
          expect(kwargs).to be_nil
          expect(options).to be_nil

          callback.call({ args: [6]}, nil, {})
        end

        dispatcher.queue.push dispatcher.command_req_queue, :publish, { topic: topic, args:[3]}, handle

        dispatcher.check_requests

        descriptor = dispatcher.queue.pop handle
        expect(descriptor.command).to eq(:publish)
        expect(descriptor.params).to eq({:result=>{:args=>[6]}, :error=>nil, :details=>{}})
        expect(descriptor.handle).to be_nil
      end
    end

  end
end
