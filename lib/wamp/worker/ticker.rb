module Wamp
  module Worker

    class Ticker
      attr_reader :redis, :ticker_key

      # Constructor
      #
      # @param name [Symbol] - The name of the worker
      def initialize(name)
        @redis = Wamp::Worker.config.redis(name)
        @ticker_key = "wamp:#{name}:tick"
      end

      # Returns the tick for the worker
      #
      # @return [Int] - The value of the tick
      def get
        self.redis.get(self.ticker_key) || 0
      end

      # Increments the tick
      #
      def increment
        self.redis.incr(self.ticker_key)
      end

    end
  end
end
