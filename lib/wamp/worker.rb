require "wamp/worker/version"
require "wamp/worker/proxy"
require "wamp/worker/redis"
require "wamp/worker/handler"
require "wamp/worker/runner"
require "redis"

module Wamp
  module Worker

    # This class is used to store the configuration of the worker
    class Config
      attr_reader :connections
      attr_writer :redis
      attr_accessor :timeout

      def initialize
        @connections = {}
        @timeout = 60
      end

      # Method to configure the registrations and subscriptions
      def routes(&callback)
        Handler.instance_eval(&callback)
      end

      # Adds a connection
      def add_connection(name, **options)
        self.connections[name] = options
      end

      # Returns the redis object
      def redis
        if @redis == nil
          ::Redis.new
        elsif @redis.is_a? ::Redis
          @redis
        else
          # TODO: Exception?
        end
      end
    end

    # The global config object
    CONFIG = Config.new
    def self.config
      CONFIG
    end

    # Method to configure the worker
    def self.setup(&callback)
      callback.call(CONFIG)
    end

    # Method to start a worker
    def self.run(name, **options)

      # Get the connection info
      connection = self.config.connections[name]
      raise RuntimeError.new("no configuration found for connection '#{name}'") unless connection

      # Create the runner and start it
      runner = Runner.new(name, self.config.redis, **(options.merge(connection)))
      runner.start

    end

    # Returns a requestor for objects to perform calls to the worker
    #
    # @param name [Symbol] - The name of the connection
    # @return [Wamp::Worker::Proxy::Requestor] - An object that can be used to make requests
    def self.requestor(name)
      Proxy::Requestor.new(self.config.redis, name)
    end

  end
end
