require "wamp/client/connection"
require_relative "handler"

module Wamp
  module Worker

    # This class is used to contain the run loop the executes on a worker
    class Runner
      attr_reader :options, :client, :proxy, :name, :redis, :verbose

      # Constructor
      def initialize(name, redis, **options)
        @options = options
        @name = name
        @redis = redis
        @client = self.options[:client] || Wamp::Client::Connection.new(self.options)
        @verbose = self.options[:verbose]
        @proxy = Proxy::Dispatcher.new(self.name, self.redis)
      end

      # Returns true if the connection is active
      #
      def active?
        self.proxy.session != nil
      end

      # Starts the run loop
      def start
        return if self.active?

        # Run this process on every EM tick
        EM.tick_loop do
          # Check for new requests
          self.proxy.process_requests
        end

        # On join, we need to subscribe and register the different handlers
        self.client.on(:join) do |session, details|
          puts "WORKER '#{self.name}' connected to the router" if self.verbose

          # Set the session
          self.proxy.session = session

          # Subscribe to the topics
          Wamp::Worker::Handler.subscriptions.each do |s|
            session.subscribe(s.topic, s.options) do |args, kwargs, details|
              s.klass.new(session, args, kwargs, details).invoke
            end
          end

          # Register for the procedures
          Wamp::Worker::Handler.registrations.each do |r|
            session.register(r.procedure, r.options) do |args, kwargs, details|
              r.klass.new(session, args, kwargs, details).invoke
            end
          end
        end

        # On leave, we will print a message
        self.client.on(:leave) do |reason, details|
          puts "WORKER '#{self.name}' disconnected from the router with reason '#{reason}'" if self.verbose

          # Clear the session
          self.proxy.session = nil
        end

        # On challenge, we will run the users challenge code
        challenge = self.options[:challange]
        self.client.on(:challenge, challenge) if challenge

        # Start the connection
        self.client.open
      end

      # Stops the run loop
      def stop
        return unless self.active?

        # Stop the even machine
        self.client.close
      end

    end
  end
end