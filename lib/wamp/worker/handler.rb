module Wamp
  module Worker

    #region Storage Objects
    class Base
      attr_reader :klass, :options

      def initialize(klass, options)
        @klass = klass
        @options = options

        raise TypeError.new("'klass' must be a Wamp::Worker::Handler type") unless klass.ancestors.include? Handler
      end
    end

    class Registration < Base
      attr_reader :procedure

      def initialize(procedure, klass, options)
        super klass, options
        @procedure = procedure
      end
    end

    class Subscription < Base
      attr_reader :topic

      def initialize(topic, klass, options)
        super klass, options
        @topic = topic
      end
    end
    #endregion

    class Handler
      attr_reader :session, :args, :kwargs, :details

      def self.subscriptions
        @@subscriptions ||= []
      end

      def self.registrations
        @@registrations ||= []
      end

      # Constructor
      #
      def initialize(session, args, kwargs, details)
        @session = session
        @args = args
        @kwargs = kwargs
        @details = details
      end

      # Subscribe the handler to a topic
      #
      # @param topic [String] - The topic to subscribe to
      # @param klass [Wamp::Worker::Handler] - The class to use
      # @param options [Hash] - Options for the subscription
      def self.subscribe(topic, klass=nil, **options)
        self.subscriptions << Subscription.new(topic, (klass || self), options)
      end

      # Register the handler for a procedure
      #
      # @param procedure [String] - The procedure to register for
      # @param klass [Wamp::Worker::Handler] - The class to use
      # @param options [Hash] - Options for the subscription
      def self.register(procedure, klass=nil, **options)
        self.registrations << Registration.new(procedure, (klass || self), options)
      end

      # The method that is called to parse the data.  Override this
      # in the subclass
      #
      def handler
      end

      # Method that invokes the handler
      #
      def invoke
        self.handler
      end

    end
  end
end