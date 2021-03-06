require "spec_helper"
require "thread"

class RequestorClass
  include Wamp::Worker::Session.new(method: :temp_session)
end

describe Wamp::Worker::Proxy do
  let(:name) { :default }
  let(:topic) { "topic" }
  let(:procedure) { "procedure" }
  let(:session) { SessionStub.new }
  let(:dispatcher) { described_class::Dispatcher.new(name, session) }
  let(:requestor) { RequestorClass.new.temp_session }

  before(:each) {
    Wamp::Worker.subscribe_topics(name, dispatcher, session)
    Wamp::Worker.register_procedures(name, dispatcher, session)
  }

  def check_method(times, method, *args)
    check_result = nil
    check_error = nil

    # Create a thread to run the dispatcher
    thread = Thread.new do
      times.times do
        descriptor = dispatcher.check_queues
        dispatcher.process(descriptor)
      end
    end

    requestor.send(method, *args) do |result, error, details|
      check_result = result
      check_error = error
    end

    # Wait for the thread to complete
    thread.join

    yield(check_result, check_error)
  end

  context "command/response flow" do

    it "executes a call command" do
      expect {
        check_method(1, :call, "normal_result", [7]) do |result, error|
          expect(result[:args][0]).to eq(10)
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a call command with invalid procedure" do
      expect {
        check_method(1, :call, "invalid_procedure", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "wamp.no_procedure", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(0)
    end

    it "executes a call command with throw error" do
      expect {
        check_method(1, :call, "throw_error", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "error", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a publish command w/o acknowledge" do
      expect {
        check_method(1, :publish, "topic", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a publish command w/ acknowledge" do
      expect {
        check_method(1, :publish, "topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to be_nil
        end
      }.to change{ NormalHandler.run_count }.by(1)
    end

    it "executes a publish command w/ acknowledge and error" do
      expect {
        check_method(1, :publish, "invalid_topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to eq({ error: "wamp.no_subscriber", args:[], kwargs:{} })
        end
      }.to change{ NormalHandler.run_count }.by(0)
    end

    it "errors on unsupported proxy command" do
      requestor.queue.push requestor.command_req_queue, :bad, {}, "handle"

      descriptor = dispatcher.check_queues
      dispatcher.process(descriptor)

      descriptor = requestor.queue.pop("handle")
      expect(descriptor.command).to eq(:bad)
      expect(descriptor.params[:error][:error]).to eq("wamp.error.runtime")
      expect(descriptor.params[:error][:args][0]).to eq("unsupported proxy command 'bad'")
    end
  end

  context "dispatcher/backgrounder flow" do

    it "executes a 'call' command" do
      expect {
        check_method(2, :call, "back.normal_result", [7]) do |result, error|
          expect(result[:args][0]).to eq(10)
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'call' command with throw error" do
      expect {
        check_method(2, :call, "back.throw_error", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to eq({ error: "error", args:[], kwargs:{} })
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/o acknowledge" do
      expect {
        check_method(1, :publish, "back.topic", [7]) do |result, error|
          expect(result).to be_nil
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "executes a 'publish' command w/ acknowledge" do
      expect {
        check_method(1, :publish, "back.topic", [7], {}, { acknowledge: true }) do |result, error|
          expect(result).to eq(1234)
          expect(error).to be_nil
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end
  end

end

