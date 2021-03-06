require "wamp/worker/version"
require "wamp/worker/proxy/requestor"
require "wamp/worker/proxy/dispatcher"
require "wamp/worker/proxy/backgrounder"
require "wamp/worker/queue"
require "wamp/worker/ticker"
require "wamp/worker/handler"
require "wamp/worker/config"
require "wamp/worker/runner"
require "wamp/client"
require "redis"

module Wamp
  module Worker

    # Used to include a requestor in any class
    #
    class Session
      def self.new(name=nil, method: :wamp_session)
        name ||= DEFAULT
        Module.new do
          define_method(method) { Proxy::Requestor.new(name) }
        end
      end
    end

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
      Wamp::Client.logger
    end

    # Sets the log level
    #
    # @param log_level [Symbol] - the desired log level
    def self.log_level=(log_level)
      Wamp::Client.log_level = log_level
    end

    # Method to configure the worker
    #
    # @param name [Symbol] - The name of the connection
    def self.configure(name=nil, &callback)
      ConfigProxy.new(self.config, name).configure(&callback)
    end

    # Method to start a worker
    #
    # @param name [Symbol] - The name of the connection
    def self.run(name=nil, **args)
      name ||= DEFAULT

      # Get the connection info
      options = Wamp::Worker.config.connection(name).merge(args)

      # Create the runner and start it
      Runner::Main.new(name, **options).start
    end

    # Registers procedures
    #
    # @param name [Symbol] - The name of the connection
    # @param proxy [Wamp::Worker::Proxy] - The proxy that will be used by the handler
    # @param session [Wamp::Client::Session] - The session
    def self.register_procedures(name, proxy, session)
      Wamp::Worker.config.registrations(name).each do |r|
        handler = -> a,k,d  {
          self.logger.debug("#{self.name} invoking handler '#{r.klass}##{r.method}' for procedure '#{r.procedure}'")
          r.klass.create(proxy, :procedure, a, k, d).invoke(r.method)
        }
        session.register(r.procedure, handler, r.options) do |result, error, details|
          if error
            self.logger.error("#{self.name} register failed '#{r.klass}##{r.method}' for procedure '#{r.procedure}'")
            self.logger.error("   error: #{error.inspect}")
          else
            self.logger.info("#{self.name} registered for '#{r.klass}##{r.method}' for procedure '#{r.procedure}'")
          end
        end
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
          self.logger.debug("#{self.name} invoking handler '#{s.klass}##{s.method}' for subscription '#{s.topic}'")
          s.klass.create(proxy, :subscription, a, k, d).invoke(s.method)
        }
        session.subscribe(s.topic, handler, s.options) do |result, error, details|
          if error
            self.logger.error("#{self.name} subscribe failed '#{s.klass}##{s.method}' for topic '#{s.topic}'")
            self.logger.error("   error: #{error.inspect}")
          else
            self.logger.info("#{self.name} subscribed '#{s.klass}##{s.method}' for topic '#{s.topic}'")
          end
        end
      end
    end

  end
end
