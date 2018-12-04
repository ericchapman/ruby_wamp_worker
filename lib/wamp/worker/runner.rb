require "thread"
require "wamp/client/connection"

module Wamp
  module Worker
    module Runner

      # This is a base class for all of the runners
      class Base
        attr_reader :name, :dispatcher

        # Constructor
        #
        # @param name [Symbol] - the name of the worker
        def initialize(name, uuid: nil)
          # Initialize the dispatcher
          @name = name || :default
          @dispatcher = Proxy::Dispatcher.new(self.name, uuid: uuid)

          # Initialize the active logic
          @active = false
          @active_semaphore = Mutex.new
        end

        def active?
          @active_semaphore.synchronize { @active }
        end

        # Starts the runner
        #
        def start
          return if self.active?

          @active_semaphore.synchronize { @active = true }
        end

        # Stops the runner
        #
        def stop
          return unless self.active?

          @active_semaphore.synchronize { @active = false }
        end

        # Returns the logger
        #
        def logger
          Wamp::Worker.logger
        end
      end

      # This class monitors the queue and returns the descriptor
      class Background < Base
        attr_reader :callback, :thread

        # Constructor
        #
        # @param name [Symbol] - the name of the worker
        def initialize(name, uuid: nil, &callback)
          super name, uuid: uuid

          @callback = callback

          # Log the event
          logger.info("#{self.class.name} '#{self.name}' created")
        end

        # Starts the runner
        #
        def start
          return if self.active?
          super

          # Start the background thread
          @thread = Thread.new do

            # The background thread will infinitely call the callback while the
            # runner is active
            while self.active?
              self.callback.call(self)
            end
            @thread = nil
          end
        end

        # Stops the runner
        #
        def stop
          return unless self.active?
          super
        end
      end

      # This class is the main runner
      class Main < Base
        attr_reader :challenge, :client,
                    :descriptor_queue, :command_monitor, :background_monitor

        # Constructor
        #
        def initialize(name=nil, **options)
          super name

          # Combine the options
          options = Wamp::Worker.config.connection(self.name).merge options

          # Setup different options
          @challenge = options[:challenge]
          @client = options[:client] || Wamp::Client::Connection.new(options)

          # Log the event
          logger.info("#{self.class.name} '#{self.name}' created with options")
          logger.info("   uri: #{options[:uri]}")
          logger.info("   realm: #{options[:realm]}")

          # Create a queue for passing messages to the main runner
          @descriptor_queue = ::Queue.new

          # Note: since all 3 of these monitors are attached to the same worker,
          # we need to lock their UUIDs together.  This will make sure they
          # delegate background tasks correctly
          uuid = self.dispatcher.uuid

          # Create a command queue monitor
          @command_monitor = Background.new(self.name, uuid: uuid) do |runner|
            descriptor = runner.dispatcher.check_command_queue
            self.descriptor_queue.push(descriptor) if descriptor
          end

          # Create a background queue monitor
          @background_monitor = Background.new(self.name, uuid: uuid) do |runner|
            descriptor = runner.dispatcher.check_background_queue
            self.descriptor_queue.push(descriptor) if descriptor
          end

          # Add the tick loop handler
          self.client.transport_class.add_tick_loop { self.tick_handler }

          # Initialize the last tick
          @last_tick = Time.now.to_i

          # Catch SIGINT
          Signal.trap('INT') { self.stop }
          Signal.trap('TERM') { self.stop }
        end

        # Starts the run loop
        #
        def start
          return if self.active?
          super

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

          # Start the monitors
          self.command_monitor.start
          self.background_monitor.start

          # Log info
          logger.info("#{self.class.name} '#{self.name}' started")

          # Start the connection
          self.client.open
        end

        # Stops the run loop
        #
        def stop
          return unless self.active?
          super

          # Stop the monitors
          self.command_monitor.stop
          self.background_monitor.stop

          # Stop the even machine
          self.client.close

          # Synchronize waiting for thread to stop
          self.command_monitor.thread&.join
          self.background_monitor.thread&.join
        end

        def join_handler(session, details)
          logger.info("#{self.class.name} runner '#{self.name}' joined session with realm '#{details[:realm]}'")

          # Set the session
          self.dispatcher.session = session

          # Register for the procedures
          Wamp::Worker.register_procedures(self.name, self.dispatcher, session)

          # Subscribe to the topics
          Wamp::Worker.subscribe_topics(self.name, self.dispatcher, session)
        end

        def leave_handler(reason, details)
          logger.info("#{self.class.name} runner '#{self.name}' left session: #{reason}")

          # Clear the session
          self.dispatcher.session = nil
        end

        def challenge_handler(authmethod, extra)
          logger.info("#{self.class.name} runner '#{self.name}' challenge")

          if self.challenge
            self.challenge.call(authmethod, extra)
          else
            raise Error::ChallengeMissing.new("client asked for '#{authmethod}' challenge, but no ':challenge' option was provided")
          end
        end

        # This method periodically checks if any work has come in from the queues
        #
        def tick_handler

          # This code will implement the ticker every second.  This tells the
          # requestors that the worker is alive
          current_time = Time.now.to_i
          if current_time > @last_tick
            self.dispatcher.increment_ticker
            @last_tick = current_time
          end

          # Loop until the queue is empty
          until self.descriptor_queue.empty? do

            # Pop the value and process it
            descriptor = self.descriptor_queue.pop
            self.dispatcher.process(descriptor)

          end
        end

      end

    end
  end
end
