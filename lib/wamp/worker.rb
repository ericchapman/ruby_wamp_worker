require "wamp/worker/version"
require "wamp/worker/session_proxy"
require "wamp/worker/redis/remote"
require "wamp/worker/redis/worker"

module Wamp
  module Worker

    # Returns a session or session proxy for the worker
    #
    # @param name [Symbol] - The name of the worker
    # @return [Session] - An object allowing session calls to be made
    def self.session(name)

    end
  end
end
