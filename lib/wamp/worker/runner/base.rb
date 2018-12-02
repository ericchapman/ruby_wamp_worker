require "thread"

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
    end
  end
end
