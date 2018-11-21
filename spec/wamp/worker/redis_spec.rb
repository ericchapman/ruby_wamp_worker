require "spec_helper"

describe Wamp::Worker::Redis do
  let(:redis) { RedisStub.new }
  let(:name) { :default }
  let(:req_queue) { described_class::Requestor.new(redis, name) }
  let(:res_queue) { described_class::Dispatcher.new(redis, name) }

  it "round trip request/response" do
    # Push the request
    params = { temp: true }
    handle = req_queue.push_request :call, params

    # Pop the request
    request = res_queue.pop_request
    expect(request.command).to eq(:call)
    expect(request.handle).to eq(handle)
    expect(request.params).to eq(params)

    # Push the response
    params = { temp: false }
    res_queue.push_response :call, handle, params

    # Pop the response
    response = req_queue.pop_response handle
    expect(response.command).to eq(:call)
    expect(response.handle).to eq(handle)
    expect(response.params).to eq(params)

    # Raises and error because there was not response
    expect {
      req_queue.pop_response(handle)
    }.to raise_error(described_class::ValueAlreadyRead)
  end

  it "timesout with worker not responding" do
    # Push the request
    params = { temp: true }
    handle = req_queue.push_request :call, params

    # Pop the request
    res_queue.pop_request

    # Raises and error because there was not response
    expect {
      req_queue.pop_response(handle)
    }.to raise_error(described_class::WorkerNotResponding)
  end

  it "resets the timeout counter" do
    count = 0
    timeout = req_queue.class::TIMEOUT
    handle = nil
    params = { temp: true }

    allow_any_instance_of(RedisStub).to receive(:get) do |object, key|
      if key.include?("tick")
        if count == timeout-10
          # Reset just before the timeout
          res_queue.increment_tick
        elsif count == timeout+10
          # REspond after the timeout would have occurred
          res_queue.push_response :call, handle, params
        end
        count += 1
      end

      object.data[key]
    end

    # Make the request
    handle = req_queue.push_request :call, params

    # Pop the response
    response = req_queue.pop_response handle
    expect(response.command).to eq(:call)
    expect(response.handle).to eq(handle)
    expect(response.params).to eq(params)
  end
end
