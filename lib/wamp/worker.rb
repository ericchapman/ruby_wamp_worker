require "wamp/worker/version"
require "wamp/worker/proxy/requestor"
require "wamp/worker/proxy/dispatcher"
require "wamp/worker/proxy/backgrounder"
require "wamp/worker/queue"
require "wamp/worker/ticker"
require "wamp/worker/handler"
require "wamp/worker/runner"
require "wamp/worker/config"
require "wamp/worker/error"
require "redis"

module Wamp
  module Worker

    # Returns the config object
    #
    def self.config
      unless defined?(@config)
        @config = Config.new
      end
      @config
    end

    # Returns the logger object
    #
    def self.logger
      unless defined?(@logger)
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
        #@logger.formatter = ENV['DYNO'] ? WithoutTimestamp.new : Pretty.new
      end
      @logger
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
      runner = Runner.new(name, **(options.merge(connection)))
      runner.start

    end

    # Returns a requestor for objects to perform calls to the worker
    #
    # @param name [Symbol] - The name of the connection
    # @return [Wamp::Worker::Proxy::Requestor] - An object that can be used to make requests
    def self.requestor(name)
      Proxy::Requestor.new(name)
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
