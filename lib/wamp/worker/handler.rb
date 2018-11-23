require 'sidekiq'
require 'wamp/client/defer'

module Wamp
  module Worker

    class Handler
      attr_reader :proxy, :command, :args, :kwargs, :details

      # Instantiates the object
      #
      def self.create(proxy, command, args, kwargs, details)
        handler = self.new
        handler.configure(proxy, command, args, kwargs, details)
        handler
      end

      # Configures the handler
      #
      def configure(proxy, command, args, kwargs, details)
        @proxy = proxy
        @command = command
        @args = args || []
        @kwargs = kwargs || {}
        @details = details || {}
      end

      # Returns the session for the call
      #
      # @return [Wamp::Client::Session, Wamp::Worker::Proxy::Requestor]
      def session
        self.proxy.session
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

    class BackgroundHandler < Handler
      include ::Sidekiq::Worker

      # Returns the session for the call
      #
      # @return [Wamp::Client::Session, Wamp::Worker::Proxy::Requestor]
      def session
        self.proxy
      end

      # Method that is run when the process is invoked on the worker
      #
      # @param command [Symbol] - The command that is being backgrounded
      # @param args [Array] - The arguments for the handler
      # @param kwargs [Hash] - The keyword arguments for the handler
      # @param details [Hash] - Other details about the call
      def perform(name, handle, command, args, kwargs, details)

        # Create a proxy to act like the session
        redis = Wamp::Worker.config.redis(name)
        proxy = Wamp::Worker::Proxy::Requestor.new(redis, name)

        # Configure the handler
        self.configure(proxy, command, args, kwargs, details)

        # Call the user code and make sure to catch exceptions
        begin
          result = self.handler
        rescue => e
          if e.is_a? Wamp::Client::CallError
            result = e
          else
            result = CallError.new('wamp.error.runtime', [e.to_s])
          end
        end

        # Only return the response if it is a procedure
        if command.to_sym == :procedure

          # Initialize the return parameters
          params = { request: details[:request], options: {}, check_defer: true }

          # Manipulate the result to be serialized
          if result == nil
            params[:result] = {}
          elsif result.is_a?(Wamp::Client::CallResult)
            params[:result] = { args: result.args, kwargs: result.kwargs }
          elsif result.is_a?(Wamp::Client::CallError)
            params[:error] = { error: result.error, args: result.args, kwargs: result.kwargs }
          else
            params[:result] = { args: [result] }
          end

          # Send the data back to the
          proxy.queue.push_background :yield, handle, params

        end
      end

      # Override the invoke method to push the process to the background
      #
      def invoke

        # Schedule the task with Redis
        self.class.perform_async(
            self.proxy.name,
            self.proxy.queue.get_background_key,
            self.command,
            self.args,
            self.kwargs,
            self.details)

        # If it is a procedure, return a defer
        if self.command == :procedure
          Wamp::Client::Defer::CallDefer.new
        else
          nil
        end

      end

      #
    end
  end
end