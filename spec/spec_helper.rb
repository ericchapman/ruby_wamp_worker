require 'simplecov'
SimpleCov.start

require "wamp/worker"

if ENV['CODECOV_TOKEN']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

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
