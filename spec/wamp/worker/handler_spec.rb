require "spec_helper"

describe Wamp::Worker::Handler do
  let(:name) { :default }
  let(:session) { SessionStub.new }
  let(:proxy) { Wamp::Worker::Proxy::Dispatcher.new(name, session) }

  it "registers the handlers" do
    config = Wamp::Worker.config

    expect(config.subscriptions.count).to eq(2)
    expect(config.subscriptions(name).count).to eq(2)
    expect(config.subscriptions(:other).count).to eq(2)

    expect(config.registrations.count).to eq(16)
    expect(config.registrations(name).count).to eq(16)
    expect(config.registrations(:other).count).to eq(2)
  end

  def setup_handlers
    Wamp::Worker.subscribe_topics(name, proxy, session)
    Wamp::Worker.register_procedures(name, proxy, session)
  end

  it "executes the normal handlers" do
    setup_handlers

    expect{
      session.publish("topic", nil, nil)

      session.call("return_error", nil, nil) do |result, error, details|
        expect(error[:error]).to eq("error")
      end

      session.call("throw_error", nil, nil) do |result, error, details|
        expect(error[:error]).to eq("error")
      end

      session.call("throw_exception", nil, nil) do |result, error, details|
        expect(error[:error]).to eq("wamp.error.runtime")
        expect(error[:args][0]).to eq("error")
      end

      session.call("call_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(5)
      end

      session.call("normal_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(6)
      end

      session.call("nil_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(nil)
      end

      session.call("proxy_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(6)
      end
    }.to change{ NormalHandler.run_count }.by(9)

  end

  it "executes the background handlers" do
    setup_handlers

    queue_count = 0
    queue_params = nil

    allow_any_instance_of(Wamp::Worker::Queue).to receive(:push) do |queue, queue_name, command, params, handle|
      queue_params = params[:result]
      queue_count += 1
      expect(command).to eq(:yield)
    end

    expect{
      session.publish("back.topic", nil, nil)

      session.call("back.return_error", nil, nil)
      expect(queue_params[:error]).to eq("error")

      session.call("back.throw_error", nil, nil)
      expect(queue_params[:error]).to eq("error")

      session.call("back.throw_exception", nil, nil)
      expect(queue_params[:error]).to eq("wamp.error.runtime")

      session.call("back.call_result", [3], nil)
      expect(queue_params[:args][0]).to eq(5)

      session.call("back.normal_result", [3], nil)
      expect(queue_params[:args][0]).to eq(6)

      session.call("back.nil_result", [3], nil)
      expect(queue_params[:args][0]).to eq(nil)
    }.to change{ BackgroundHandler.run_count }.by(7)

    expect(queue_count).to eq(6)
  end

  context "progress" do
    before(:each) {
      setup_handlers
    }

    it "reports the progress in the foreground" do
      count = 0

      session.call("progress_result", [3], nil, { receive_progress: true }) do |result, error, details|
        case count
        when 0
          expect(result[:args][0]).to eq(0)
          expect(details[:progress]).to eq(true)
        when 1
          expect(result[:args][0]).to eq(0.5)
          expect(details[:progress]).to eq(true)
        when 2
          expect(result[:args][0]).to eq(1.0)
          expect(details[:progress]).to eq(true)
        else
          expect(result[:args][0]).to eq(7)
          expect(details[:progress]).not_to eq(true)
        end

        count += 1
      end

      expect(count).to eq(4)
    end

    it "reports the progress in the background" do
      count = 0

      allow_any_instance_of(Wamp::Worker::Queue).to receive(:push) do |queue, queue_name, command, params, handle|
        result = params[:result]
        options = params[:options]

        case count
        when 0
          expect(result[:args][0]).to eq(0)
          expect(options[:progress]).to eq(true)
        when 1
          expect(result[:args][0]).to eq(0.5)
          expect(options[:progress]).to eq(true)
        when 2
          expect(result[:args][0]).to eq(1.0)
          expect(options[:progress]).to eq(true)
        else
          expect(result[:args][0]).to eq(7)
          expect(options[:progress]).not_to eq(true)
        end

        count += 1
      end

      session.call("back.progress_result", [3], nil, { receive_progress: true })

      expect(count).to eq(4)
    end
  end

end

