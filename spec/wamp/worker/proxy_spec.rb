require "spec_helper"
require "thread"

describe Wamp::Worker::Proxy do
  let(:name) { :default }
  let(:topic) { "topic" }
  let(:procedure) { "procedure" }
  let(:session) { SessionStub.new }
  let(:dispatcher) { described_class::Dispatcher.new(name, session) }
  let(:requestor) { described_class::Requestor.new(name) }

  before(:each) {
    Wamp::Worker.subscribe_topics(name, dispatcher, session)
    Wamp::Worker.register_procedures(name, dispatcher, session)
  }

  context "command/response flow" do

    def check_method(method, *args)
      check_result = nil
      check_error = nil

      # Create a thread to run the dispatcher
      thread = Thread.new do
        descriptor = dispatcher.check_command_queue
        dispatcher.process(descriptor)
      end

      requestor.send(method, *args) do |result, error, details|
        check_result = result
        check_error = error
      end

      # Wait for the thread to complete
      thread.join

      yield(check_result, check_error)
    end

    it "executes a 'call' command" do
      expect {
        check_method(:call, "normal_result", [7]) do |result, error|
          expect(result[:args][0]).to eq(10)
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a 'call' command with invalid procedure" do
      expect {
        check_method(:call, "invalid_procedure", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "no registration found", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(0)
    end

    it "executes a 'call' command with throw error" do
      expect {
        check_method(:call, "throw_error", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "error", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/o acknowledge" do
      expect {
        check_method(:publish, "topic", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/ acknowledge" do
      expect {
        check_method(:publish, "topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/ acknowledge and error" do
      expect {
        check_method(:publish, "invalid_topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to eq({ error: "no subscriber found", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(0)
    end

    it "errors on unsupported proxy command" do
      requestor.queue.push requestor.command_req_queue, :bad, {}, "handle"

      descriptor = dispatcher.check_command_queue
      dispatcher.process(descriptor)

      descriptor = requestor.queue.pop("handle")
      expect(descriptor.command).to eq(:bad)
      expect(descriptor.params[:error][:error]).to eq("unsupported proxy command 'bad'")
    end
  end

  context "dispatcher/backgrounder flow" do

    def check_method(method, *args)
      check_result = nil
      check_error = nil

      # Create a thread to run the dispatcher
      thread1 = Thread.new do
        descriptor = dispatcher.check_command_queue
        dispatcher.process(descriptor)
      end

      if method == :call
        thread2 = Thread.new do
          descriptor = dispatcher.check_background_queue
          dispatcher.process(descriptor)
        end
      else
        thread2 = nil
      end

      requestor.send(method, *args) do |result, error, details|
        check_result = result
        check_error = error
      end

      # Wait for the thread to complete
      thread1.join
      thread2.join if method == :call

      yield(check_result, check_error)
    end

    it "executes a 'call' command" do
      expect {
        check_method(:call, "back.normal_result", [7]) do |result, error|
          expect(result[:args][0]).to eq(10)
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'call' command with throw error" do
      expect {
        check_method(:call, "back.throw_error", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "error", args:[], kwargs:{} })
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/o acknowledge" do
      expect {
        check_method(:publish, "back.topic", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/ acknowledge" do
      expect {
        check_method(:publish, "back.topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end
  end

end

