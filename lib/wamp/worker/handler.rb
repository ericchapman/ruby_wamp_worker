module Wamp
  module Worker

    class Handler
      attr_reader :session, :args, :kwargs, :details


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
      def self.subscribe(topic, klass=nil, name: nil, **options)
        klass ||= self
        Wamp::Worker::configure name do
          subscribe topic, klass, **options
        end
      end

      # Register the handler for a procedure
      #
      # @param procedure [String] - The procedure to register for
      # @param klass [Wamp::Worker::Handler] - The class to use
      # @param options [Hash] - Options for the subscription
      def self.register(procedure, klass=nil, name: nil,**options)
        klass ||= self
        Wamp::Worker::configure name do
          register procedure, klass, **options
        end
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