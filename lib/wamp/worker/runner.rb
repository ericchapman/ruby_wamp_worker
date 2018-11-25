require "wamp/client/connection"
require_relative "handler"

module Wamp
  module Worker

    # This class is used to contain the run loop the executes on a worker
    class Runner
      attr_reader :options, :client, :proxy, :name, :verbose

      # Constructor
      def initialize(name, **options)
        @options = options
        @name = name
        @client = self.options[:client] || Wamp::Client::Connection.new(self.options)
        @verbose = self.options[:verbose]

        # Create the dispatcher proxy
        redis = Wamp::Worker.config.redis(self.name)
        @proxy = Proxy::Dispatcher.new(redis, self.name)

        # Add the tick loop handler
        self.client.transport_class.add_tick_loop { self.tick_handler }
      end

      # Returns true if the connection is active
      #
      # @return [Bool] - true if the runner is active
      def active?
        self.proxy.session != nil
      end

      # Starts the run loop
      def start
        return if self.active?

        # On join, we need to subscribe and register the different handlers
        self.client.on :join do |session, details|
          self.join_handler session, details
        end

        # On leave, we will print a message
        self.client.on :leave do |reason, details|
          self.leave_handler(reason, details)
        end

        # On challenge, we will run the users challenge code
        self.client.on :challenge do |authmethod, details|
          self.challenge_handler(authmethod, details)
        end

        # Start the connection
        self.client.open
      end

      # Stops the run loop
      def stop
        return unless self.active?

        # Stop the even machine
        self.client.close
      end

      def join_handler(session, details)
        puts "WORKER '#{self.name}' connected to the router" if self.verbose

        # Set the session
        self.proxy.session = session

        # Register for the procedures
        Wamp::Worker.register_procedures(self.name, self.proxy, session)

        # Subscribe to the topics
        Wamp::Worker.subscribe_topics(self.name, self.proxy, session)
      end

      def leave_handler(reason, details)
        puts "WORKER '#{self.name}' disconnected from the router with reason '#{reason}'" if self.verbose

        # Clear the session
        self.proxy.session = nil
      end

      def challenge_handler(authmethod, extra)
        challenge = self.options[:challenge]
        if challenge
          challenge.call(authmethod, extra)
        else
          raise RuntimeError, "client asked for '#{authmethod}' challenge, but no ':challenge' option was provided"
        end
      end

      def tick_handler
        self.proxy.process_requests
      end

    end
  end
end