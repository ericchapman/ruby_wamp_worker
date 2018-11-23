require "spec_helper"

describe Wamp::Worker::Runner do

  before(:each) {
    @topic = "com.example.topic"
    @procedure = "com.example.procedure"
    @back = "_back"

    # Override the config
    config = Wamp::Worker::Config.new
    allow(Wamp::Worker).to receive(:config).and_return(config)

    # Override redis
    redis = RedisStub.new
    allow(::Redis).to receive(:new).and_return(redis)

    # Can't see them in the block
    topic = @topic
    procedure = @procedure
    back = @back

    # Create the subscriptions
    Wamp::Worker.configure do
      namespace :test do
        subscribe topic, SubscribeHandler
        register procedure, RegisterHandler
        subscribe topic+back, SubscribeBackgroundHandler
        register procedure+back, RegisterBackgroundHandler
      end
    end
  }

  it "registers and subscribes" do

    # Create the runner
    runner = described_class.new :test, client: ClientStub.new({})

    # Check attributes
    expect(runner.active?).to eq(false)
    expect(runner.proxy.session).to be_nil

    # Start it
    runner.start

    # Check attributes
    expect(runner.active?).to eq(true)
    expect(runner.proxy.session).to be(runner.client.session)

    # Check that the handlers get called

    expect {
      runner.proxy.session.call @procedure, [3] do |result, error, details|
        expect(result[:args][0]).to eq(5)
      end
    }.to change{ RegisterHandler.run_count }.by(1)

    expect {
      runner.proxy.session.publish @topic
    }.to change{ SubscribeHandler.run_count }.by(1)

    allow_any_instance_of(SessionStub).to receive(:yield) do |session, request, result, options, check_defer|
      expect(result.args[0]).to eq(5)
    end

    expect {
      runner.proxy.session.call @procedure+@back, [3] do |result, error, details|
        expect(result[:args][0].is_a?(Wamp::Client::Defer::CallDefer)).to eq(true)
      end

      runner.tick_handler
    }.to change{ RegisterBackgroundHandler.run_count }.by(1)

    expect {
      runner.proxy.session.publish @topic+@back
      runner.tick_handler
    }.to change{ SubscribeBackgroundHandler.run_count }.by(1)

    # Stop the runner
    runner.stop

    # Check attributes
    expect(runner.active?).to eq(false)
    expect(runner.proxy.session).to be_nil
  end

  context "challenge" do
    it "errors if challenge is called but no method was passed in" do
      runner = described_class.new :test, client: ClientStub.new({should_challenge: true})

      # Errors because the callback wasn't defined
      expect {
        runner.start
      }.to raise_error(RuntimeError)
    end

    it "does not error when the challenge is defined" do
      value = 0

      # Create the runner passing it the challenge method
      runner = described_class.new :test,
                                   challenge: -> authmethod, details {value += 1},
                                   client: ClientStub.new({should_challenge: true})

      # Start the runner
      runner.start

      # Expect that the challenge method was calle
      expect(value).to eq(1)
    end

  end
end
