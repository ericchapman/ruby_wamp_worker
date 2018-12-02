require "wamp/client/connection"
require_relative "handler"
require_relative "error"

module Wamp
  module Worker

    # This class is used to contain the run loop the executes on a worker
    class Runner
      attr_reader :client, :proxy, :name, :challenge, :verbose

      # Constructor
      def initialize(name=nil, **options)
        @name = name&.to_sym || :default

        options = Wamp::Worker.config.connection(self.name).merge options

        puts "WAMP: Starting runner with options #{options}"

        # Setup different options
        @verbose = options[:verbose]
        @challenge = options[:challenge]
        @client = options[:client] || Wamp::Client::Connection.new(options)
        @proxy = Proxy::Dispatcher.new(self.name)

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
        if self.challenge
          self.challenge.call(authmethod, extra)
        else
          raise Error::ChallengeMissing.new("client asked for '#{authmethod}' challenge, but no ':challenge' option was provided")
        end
      end

      def tick_handler
        current_time = Time.now.to_ms

        # This logic makes sure we don't hit the redis server too often
        return unless current_time > @next_tick

        # Print a tick count to the screen
        puts "WORKER tick #{@tick}" if self.verbose
        @tick += 1

        # Call the task
        self.proxy.check_requests

        # Increment the counter
        @next_tick = current_time + @tick_period
      end

    end
  end
end