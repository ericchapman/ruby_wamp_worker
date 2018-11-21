require "wamp/worker/version"
require "wamp/worker/proxy"
require "wamp/worker/redis"

module Wamp
  module Worker

    # Returns a session or session proxy for the worker
    #
    # @param name [Symbol] - The name of the worker
    # @return [Session] - An object allowing session calls to be made
    def self.session(name)

    end

    # Constructor
    #
    # @param name [Symbol] - The name of the worker
    def initialize

    end

    # Main Event Machine Loop
    #
    #
    def main

    end
  end
end
