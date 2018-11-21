require "wamp/client/connection"

module Wamp
  module Worker

    # This class is used to contain the run loop the executes on a worker
    class RunLoop
      attr_reader :options, :client, :remote, :name, :requests,
                  :registrations, :subscriptions, :active, :verbose

      # Constructor
      def initialize(**options)
        @options = options || {}
        @registrations = []
        @subscriptions = []
        @requests = {}
        @name = self.options[:name] || :default
        @client = self.options[:client] || Wamp::Client::Connection.new(self.options)
        @remote = Redis::Remote.new(self.name, self.options[:redis])
        @verbose = self.options[:verbose]
        @active = false
      end

      # Starts the run loop
      def start
        return if self.active

        # Run this process on every EM tick
        EM.tick_loop do
          self.loop
        end

        # Print message on session join
        self.client.on(:connected) do |session, details|
          puts "WORKER '#{self.name}' connected to the router" if self.verbose
          @active = true
        end

        # Print message on session join
        self.client.on(:disconnected) do |reason, details|
          puts "WORKER '#{self.name}' disconnected from the router with reason '#{reason}'" if self.verbose
          @active = false
        end

        # Start the connection
        self.client.open
      end

      # Stops the run loop
      def stop
        return unless self.active

        # Stop the even machine
        self.client.close
      end

      # Executes on each EM tick
      def loop
        # Increment the ticker to show that the worker is still alive
        self.remote.increment_tick

        # Loop until all requests have been serviced
        no_requests = false
        until no_requests do
          request = self.remote.get_request
          if request
            # TODO: Process the request
          else
            no_requests = true
          end
        end
      end

    end
  end
end