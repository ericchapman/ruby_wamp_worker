require_relative "proxy/backgrounder"
require 'wamp/client/defer'
require 'json'

module Wamp
  module Worker

    module BaseHandler
      def self.included(base)
        attr_reader :proxy, :command, :args, :kwargs, :details

        base.extend(ClassMethods)
      end

      module ClassMethods

        # Instantiates the object
        #
        def create(proxy, command, args, kwargs, details)
          handler = self.new
          handler.configure(proxy, command, args, kwargs, details)
          handler
        end

        # Subscribe the handler to a topic
        #
        # @param topic [String] - The topic to subscribe to
        # @param method [Symbol] - The name of the method to execute
        # @param options [Hash] - Options for the subscription
        def subscribe(topic, method, name: nil, **options)
          klass = self
          Wamp::Worker::configure name do
            subscribe topic, klass, method, **options
          end
        end

        # Register the handler for a procedure
        #
        # @param procedure [String] - The procedure to register for
        # @param method [Symbol] - The name of the method to execute
        # @param options [Hash] - Options for the subscription
        def register(procedure, method, name: nil, **options)
          klass = self
          Wamp::Worker::configure name do
            register procedure, klass, method, **options
          end
        end
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

    end

    module Handler

      def self.included(base)
        base.class_eval do
          include BaseHandler
        end
      end

      # Returns the session for the call
      #
      # @return [Wamp::Client::Session, Wamp::Worker::Proxy::Requestor]
      def session
        self.proxy.session
      end

      # Method that invokes the handler
      #
      def invoke(method)
        self.send(method)
      end

    end

    module BackgroundHandler

      def self.included(base)
        base.class_eval do
          include BaseHandler

          # Use Sidekiq
          require 'sidekiq'
          include ::Sidekiq::Worker
        end
      end

      # Returns the session for the call
      #
      # @return [Wamp::Client::Session, Wamp::Worker::Proxy::Requestor]
      def session
        self.proxy
      end

      # Method that is run when the process is invoked on the worker
      #
      # @param method [Symbol] - The name of the method to execute
      # @param command [Symbol] - The command that is being backgrounded
      # @param args [Array] - The arguments for the handler
      # @param kwargs [Hash] - The keyword arguments for the handler
      # @param details [Hash] - Other details about the call
      def perform(method, proxy_name, proxy_handle, command, args, kwargs, details)

        # Create a proxy to act like the session.  Use a backgrounder so we also
        # get the "yield" method
        @proxy = Proxy::Backgrounder.new(proxy_name, proxy_handle)

        # Deserialize the arguments as symbols
        args = JSON.parse(args, :symbolize_names => true)
        kwargs = JSON.parse(kwargs, :symbolize_names => true)
        details = JSON.parse(details, :symbolize_names => true)

        # Get the st ID
        request = details[:request]

        # Add the proxy to the details as a "session"
        details[:session] = self.proxy

        # Configure the handler
        self.configure(self.proxy, command, args, kwargs, details)

        # Call the user code and make sure to catch exceptions
        begin
          result = self.send(method)
        rescue Wamp::Client::CallError => e
          result = e
        rescue StandardError => e
          result = Wamp::Client::CallError.new('wamp.error.runtime', [e.to_s])
        end

        # Only return the response if it is a procedure
        if command.to_sym == :procedure

          # Manipulate the result to be serialized
          response = Wamp::Worker::Proxy::Response.from_result(result)&.to_hash || {}

          # Send the data back to the
          self.proxy.yield request, response, {}, true

        end
      end

      # Override the invoke method to push the process to the background
      #
      def invoke(method)

        # Send the task to Sidekiq
        #
        # Note: We are explicitly serializing the args, kwargs, details
        # so that we can deserialize and have them appear as symbols in
        # the handler.  Also need to remove the session before serialization
        details = self.details.clone
        details.delete(:session)

        self.class.perform_async(
            method,
            self.proxy.name,
            self.proxy.background_res_queue,
            self.command,
            self.args.to_json,
            self.kwargs.to_json,
            details.to_json)

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