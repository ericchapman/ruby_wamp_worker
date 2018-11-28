module Wamp
  module Worker

    class Ticker
      attr_accessor :redis

      # Constructor
      #
      # @param name [Symbol] - The name of the worker
      def initialize(name)
        @redis = Wamp::Worker.config.redis(name)
      end

      # Returns the tick for the worker
      #
      # @return [Int] - The value of the tick
      def get(key_name)
        self.redis.get(key_name) || 0
      end

      # Increments the tick
      #
      def increment(key_name)
        self.redis.incr(key_name)
      end

    end
  end
end
