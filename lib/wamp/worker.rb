require "wamp/worker/version"
require "wamp/worker/proxy"
require "wamp/worker/redis"
require "wamp/worker/handler"
require "wamp/worker/runner"
require "wamp/worker/config"
require "wamp/worker/error"
require "redis"

module Wamp
  module Worker

    # The global config object
    CONFIG = Config.new

    # Returns the config object
    #
    # @param name [Symbol] - The name of the connection
    # @return [Config] - Returns the global config object
    def self.config
      CONFIG
    end

    # Method to configure the worker
    #
    # @param name [Symbol] - The name of the connection
    def self.configure(name=nil, &callback)
      ConfigProxy.new(self.config, name).configure(&callback)
    end

    # Method to start a worker
    def self.run(name, **options)

      # Get the connection info
      connection = self.config.connections[name]
      raise Error::UndefinedConfiguration.new("no configuration found for connection '#{name}'") unless connection

      # Create the runner and start it
      runner = Runner.new(name, self.config.redis(name), **(options.merge(connection)))
      runner.start

    end

    # Returns a requestor for objects to perform calls to the worker
    #
    # @param name [Symbol] - The name of the connection
    # @return [Wamp::Worker::Proxy::Requestor] - An object that can be used to make requests
    def self.requestor(name)
      Proxy::Requestor.new(self.config.redis(name), name)
    end

    # Registers procedures
    #
    # @param name [Symbol] - The name of the connection
    # @param proxy [Wamp::Worker::Proxy] - The proxy that will be used by the handler
    # @param session [Wamp::Client::Session] - The session
    def self.register_procedures(name, proxy, session)
      Wamp::Worker.config.registrations(name).each do |r|
        handler = -> a,k,d  {
          r.klass.create(proxy, :procedure, a, k, d).invoke(r.method)
        }
        session.register(r.procedure, handler, r.options)
      end
    end

    # Subscribe to topics
    #
    # @param name [Symbol] - The name of the connection
    # @param proxy [Wamp::Worker::Proxy] - The proxy that will be used by the handler
    # @param session [Wamp::Client::Session] - The session
    def self.subscribe_topics(name, proxy, session)
      Wamp::Worker.config.subscriptions(name).each do |s|
        handler = -> a, k, d {
          s.klass.create(proxy, :subscription, a, k, d).invoke(s.method)
        }
        session.subscribe(s.topic, handler, s.options)
      end
    end

  end
end
