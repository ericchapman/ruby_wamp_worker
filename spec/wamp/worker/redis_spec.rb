require "spec_helper"

describe Wamp::Worker::Redis do
  let(:redis) { RedisStub.new }
  let(:name) { :default }
  let(:queue) { described_class::Queue.new(redis, name) }

  it "round trip request/response" do
    # Push the request
    params = { temp: true }
    handle = queue.push_request :call, params

    # Pop the request
    request = queue.pop_request
    expect(request.command).to eq(:call)
    expect(request.handle).to eq(handle)
    expect(request.params).to eq(params)

    # Push the response
    params = { temp: false }
    queue.push_response :call, handle, params

    # Pop the response
    response = queue.pop_response handle
    expect(response.command).to eq(:call)
    expect(response.handle).to eq(handle)
    expect(response.params).to eq(params)

    # Raises and error because there was not response
    expect {
      queue.pop_response(handle)
    }.to raise_error(described_class::ValueAlreadyRead)
  end

  it "round trip background" do
    # Push the request
    params = { temp: true }
    queue.push_background :yield, queue.get_background_key, params

    # Pop the request
    request = queue.pop_background
    expect(request.command).to eq(:yield)
    expect(request.handle).to eq(queue.get_background_key)
    expect(request.params).to eq(params)
  end

  it "timeout with worker not responding" do
    # Push the request
    params = { temp: true }
    handle = queue.push_request :call, params

    # Pop the request
    queue.pop_request

    # Raises and error because there was not response
    expect {
      queue.pop_response(handle)
    }.to raise_error(described_class::WorkerNotResponding)
  end

  it "timeout with no response" do
    old_timeout = Wamp::Worker.config[:default][:timeout]
    Wamp::Worker.config[:default][:timeout] = 0

    # Push the request
    params = { temp: true }
    handle = queue.push_request :call, params

    # Pop the request
    queue.pop_request

    # Raises and error because there was not response
    expect {
      queue.pop_response(handle)
    }.to raise_error(described_class::ResponseTimeout)

    Wamp::Worker.config[:default][:timeout] = old_timeout
  end

  it "resets the timeout counter" do
    count = 0
    timeout = queue.class::IDLE_TIMEOUT
    handle = nil
    params = { temp: true }

    allow_any_instance_of(RedisStub).to receive(:get) do |object, key|
      if key.include?("tick")
        if count == timeout-10
          # Reset just before the timeout
          queue.increment_tick
        elsif count == timeout+10
          # REspond after the timeout would have occurred
          queue.push_response :call, handle, params
        end
        count += 1
      end

      object.data[key]
    end

    # Make the request
    handle = queue.push_request :call, params

    # Pop the response
    response = queue.pop_response handle
    expect(response.command).to eq(:call)
    expect(response.handle).to eq(handle)
    expect(response.params).to eq(params)
  end
end
