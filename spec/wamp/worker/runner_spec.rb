require "spec_helper"

describe Wamp::Worker::Runner do
  let(:name) { :other }
  let(:runner) { described_class::Main.new(name) }
  let(:requestor) { Wamp::Worker.requestor(name) }

  def execute_runner

    # Start the runner
    runner.start

    # Start it and the event machine on a different thread
    thread = Thread.new do
      EM.run {}
    end

    yield

    # Stop the event machine
    runner.client.transport_class.stop_event_machine
    thread.join

    # Stop the runner
    runner.stop

  end

  it "registers and subscribes" do

    # Check attributes
    expect(runner.active?).to eq(false)
    expect(runner.dispatcher.session).to be_nil

    execute_runner do

      # Check attributes
      expect(runner.active?).to eq(true)
      expect(runner.dispatcher.session).to be(runner.client.session)

      # Check that some of the handlers work
      expect{
        requestor.call("other.call_result", [3], nil) do |result, error, details|
          expect(result[:args][0]).to eq(5)
        end
      }.to change{ NormalHandler.run_count }.by(1)

      expect{
        requestor.call("back.other.call_result", [4], nil) do |result, error, details|
          expect(result[:args][0]).to eq(6)
        end
      }.to change{ BackgroundHandler.run_count }.by(1)

    end

    # Check attributes
    expect(runner.active?).to eq(false)
    expect(runner.dispatcher.session).to be_nil
  end

  it "synchronizes the UUID between all of the runners" do
    uuid = runner.dispatcher.uuid
    expect(runner.queue_monitor.dispatcher.uuid).to eq(uuid)
  end

  it "increments the ticker" do
    expect(runner.dispatcher.ticker.get(runner.dispatcher.ticker_key)).to eq(0)
    execute_runner do
      sleep(2)
    end
    expect(runner.dispatcher.ticker.get(runner.dispatcher.ticker_key)).to eq(2)
  end

  context "challenge" do
    it "errors if challenge is called but no method was passed in" do
      runner = described_class::Main.new :test, client: ClientStub.new({should_challenge: true})

      # Errors because the callback wasn't defined
      expect {
        runner.start
      }.to raise_error(ArgumentError)

      # Ensure that the runner terminated
      expect(runner.active?).to eq(false)
    end

    it "does not error when the challenge is defined" do
      value = 0

      # Create the runner passing it the challenge method
      runner = described_class::Main.new :test,
                                         challenge: -> authmethod, details {value += 1},
                                         client: ClientStub.new({should_challenge: true})

      # Start the runner
      runner.start

      # Expect that the challenge method was called
      expect(value).to eq(1)

      # Stop the runner
      runner.stop
    end

  end
end
