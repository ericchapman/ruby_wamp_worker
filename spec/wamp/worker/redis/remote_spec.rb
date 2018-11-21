require "spec_helper"

describe Wamp::Worker::Redis::Remote do
  let(:redis) { RedisStub.new }
  let(:name) { :default }
  let(:remote) { described_class.new(name, redis) }

  it "sends the request" do
    args = { temp: true }
    handle = remote.send_request :call, args

    expected = {
        command: :call,
        handle: handle,
        args: {temp:true}
    }
    expect(redis.data[remote.get_commands_key]).to eq([expected.to_json])
  end
end
