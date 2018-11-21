require 'simplecov'
SimpleCov.start do
  add_filter 'spec/'
end

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "wamp/worker"

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }
