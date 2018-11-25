require "spec_helper"

describe Wamp::Worker::Runner do

  before(:each) {
    # Override redis
    redis = RedisStub.new
    allow(::Redis).to receive(:new).and_return(redis)
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

    # Check that some of the handlers work
    expect{
      runner.proxy.session.call("normal_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(6)
      end
    }.to change{ NormalHandler.run_count }.by(1)

    expect{
      runner.proxy.session.call("call_result", [3], nil) do |result, error, details|
        expect(result[:args][0]).to eq(5)
      end
    }.to change{ NormalHandler.run_count }.by(1)

    # Stop the runner
    runner.stop

    # Check attributes
    expect(runner.active?).to eq(false)
    expect(runner.proxy.session).to be_nil
  end

  context "background" do
    let(:runner) { described_class.new :test, client: ClientStub.new({}) }
    before(:each) { runner.start }

    def make_call(procedure, args, kwargs, &callback)
      runner.proxy.session.call procedure, args, kwargs do |result, error, details|
        callback.call(result, error, details)
      end

      runner.tick_handler
    end

    it "handles a normal result" do
      expect{
        make_call("back.normal_result", [3], nil) do |result, error, details|
          expect(result[:args][0]).to eq(6)
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

    it "handles a call result" do
      expect{
        make_call("back.call_result", [3], nil) do |result, error, details|
          expect(result[:args][0]).to eq(5)
        end
      }.to change{ BackgroundHandler.run_count }.by(1)
    end

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
