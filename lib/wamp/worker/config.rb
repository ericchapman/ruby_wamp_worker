require "redis"
require_relative "error"

module Wamp
  module Worker

    #region Storage Objects
    class Handle
      attr_reader :klass, :method, :options

      def initialize(klass, method, options)
        @klass = klass
        @method = method
        @options = options

        unless klass.ancestors.include? BaseHandler
          raise Error::HandleTypeError.new("'klass' must be a Wamp::Worker::Handler type")
        end
      end
    end

    class Registration < Handle
      attr_reader :procedure

      def initialize(procedure, klass, method, options)
        super klass, method, options
        @procedure = procedure
      end
    end

    class Subscription < Handle
      attr_reader :topic

      def initialize(topic, klass, method, options)
        super klass, method, options
        @topic = topic
      end
    end
    #endregion

    # This class is a config proxy that lets you specify the name globally
    #
    class ConfigProxy
      attr_reader :name, :config

      def initialize(config, name=nil)
        @name = name || :default
        @config = config
      end

      # Sets the timeout value
      #
      def timeout(seconds)
        self[:timeout] = seconds
      end

      # Sets the Redis connection
      #
      def redis(connection)
        self[:redis] = connection
      end

      # Connection options
      #
      def connection(**options)
        self[:connection] = options
      end

      # Subscribe the handler to a topic
      #
      # @param topic [String] - The topic to subscribe to
      # @param klass [Wamp::Worker::Handler] - The class to use
      # @param method [Symbol] - The name of the method to execute
      # @param options [Hash] - Options for the subscription
      def subscribe(topic, klass, method, **options)
        subscriptions = self[:subscriptions] || []
        subscriptions << Subscription.new(topic, klass, method, options)
        self[:subscriptions] = subscriptions
      end

      # Register the handler for a procedure
      #
      # @param procedure [String] - The procedure to register for
      # @param klass [Wamp::Worker::Handler] - The class to use
      # @param method [Symbol] - The name of the method to execute
      # @param options [Hash] - Options for the subscription
      def register(procedure, klass, method, **options)
        registrations = self[:registrations] || []
        registrations << Registration.new(procedure, klass, method, options)
        self[:registrations] = registrations
      end

      # Allows the user to specify a name and configure accordingly
      #
      # @param name [Symbol] - The name for the connection
      def namespace(name, &callback)
        name ||= :default

        # Create a new proxy and call it
        proxy = ConfigProxy.new(self.config, name)

        # Set the base class for the new namespace
        proxy[:base] = self.name

        # Execute the proxy methods
        proxy.instance_eval(&callback)
      end

      # Allows the user to configure without typing "config."
      #
      def configure(&callback)
        self.instance_eval(&callback)
      end

      # Sets the attribute using the name
      #
      # @param attribute [Symbol] - The attribute
      # @param value - The value for the attribute
      def []=(attribute, value)
        self.config[self.name][attribute] = value
      end

      # Gets the attribute using the name
      #
      # @param attribute [Symbol] - The attribute
      def [](attribute)
        self.config[self.name][attribute]
      end
    end

    # This class is used to store the configuration of the worker
    #
    class Config
      attr_reader :settings

      def initialize
        @settings = {}
      end

      # Returns the connection options
      #
      # @param name [Symbol] - The name of the connection
      def connection(name=nil)
        name ||= :default
        connection = {}

        self.parents(name, :connection) do |name, value|
          connection = connection.merge(value || {})
        end

        connection
      end

      # Returns the timeout value
      #
      # @param name [Symbol] - The name of the connection
      def timeout(name=nil)
        name ||= :default
        timeout = 60

        self.parents(name, :timeout) do |name, value|
          timeout = value if value
        end

        timeout
      end

      # Returns the redis value
      #
      # @param name [Symbol] - The name of the connection
      def redis(name=nil)
        name ||= :default
        redis = nil

        self.parents(name, :redis) do |name, value|
          redis = value if value
        end

        # If it is not a redis object, create one using it as the options
        if redis == nil
          redis = ::Redis.new
        elsif not redis.is_a? ::Redis
          redis = ::Redis.new(redis)
        end

        redis
      end

      # Returns the subscriptions
      #
      # @param name [Symbol] - The name of the connection
      def subscriptions(name=nil)
        name ||= :default
        subscriptions = []

        self.parents(name, :subscriptions) do |name, value|
          subscriptions += (value || [])
        end

        subscriptions
      end

      # Returns the registrations
      #
      # @param name [Symbol] - The name of the connection
      def registrations(name=nil)
        name ||= :default
        registrations = []

        self.parents(name, :registrations) do |name, value|
          registrations += (value || [])
        end

        registrations
      end

      # Returns the settings for a particular connection
      #
      # @param name [Symbol] - The name of the connection
      def [](name)
        settings = self.settings[name] || {}
        self.settings[name] = settings
        settings
      end

      # Iterates through the base classes and fetches the value
      #
      def parents(name, attribute, &callback)
        # If we got a nil name, return
        return if name == nil

        # Get the base class.  Set to :default if nil
        base = self[name][:base]
        if base == nil and name != :default
          base = :default
        end

        # Execute the parent first
        self.parents(base, attribute, &callback)

        # Execute self
        callback.call(name, self[name][attribute])
      end
    end

  end
end
