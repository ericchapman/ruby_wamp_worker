require "spec_helper"

describe Wamp::Worker::Runner do

  before(:each) {
    @topic = "com.example.topic"
    @procedure = "com.example.procedure"

    # Override the config
    config = Wamp::Worker::Config.new
    allow(Wamp::Worker).to receive(:config).and_return(config)

    # Can't see them in the block
    topic = @topic
    procedure = @procedure

    # Create the subscriptions
    Wamp::Worker.configure do
      namespace :test do
        subscribe topic, SubscribeHandler
        register procedure, RegisterHandler
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
    runner.proxy.session.call @procedure, [3] do |result, error, details|
      expect(result[:args][0]).to eq(5)
    end
    runner.proxy.session.publish @topic

    # Check that the handlers were called
    expect(SubscribeHandler.run_count).to eq(1)
    expect(RegisterHandler.run_count).to eq(1)

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
