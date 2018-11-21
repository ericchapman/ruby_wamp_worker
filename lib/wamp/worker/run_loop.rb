require "wamp/client/connection"

module Wamp
  module Worker

    # This class is used to contain the run loop the executes on a worker
    class RunLoop
      attr_reader :options, :client, :proxy, :name, :requests,
                  :registrations, :subscriptions, :active, :verbose

      # Constructor
      def initialize(**options)
        @options = options || {}
        @registrations = []
        @subscriptions = []
        @requests = {}
        @name = self.options[:name] || :default
        @client = self.options[:client] || Wamp::Client::Connection.new(self.options)
        @verbose = self.options[:verbose]
        @active = false

        dispatcher = Redis::Dispatcher.new(self.name, self.options[:redis])
        @proxy = Proxy::Worker.new(dispatcher)
      end

      # Starts the run loop
      def start
        return if self.active

        # Run this process on every EM tick
        EM.tick_loop do
          # Check for new requests
          self.proxy.process_requests
        end

        self.client.on(:join) do |session, details|
          puts "WORKER '#{self.name}' connected to the router" if self.verbose
          self.proxy.session = session
          @active = true
        end

        # Print message on session join
        self.client.on(:leave) do |reason, details|
          puts "WORKER '#{self.name}' disconnected from the router with reason '#{reason}'" if self.verbose
          self.proxy.session = nil
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

    end
  end
end