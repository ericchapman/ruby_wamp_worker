require 'simplecov'
SimpleCov.start do
  add_filter 'spec/'
end

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "wamp/worker"

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }

require 'sidekiq/testing'
Sidekiq::Testing.inline!

Wamp::Worker.log_level = :error

RSpec.configure do |config|
  config.before(:each) {
    stub_redis
    stub_client
  }
end

def stub_redis
  allow(::Redis).to receive(:new).and_return(RedisStub.new)
end

def stub_client
  allow(::Wamp::Client::Connection).to receive(:new).and_return(ClientStub.new({}))
end
