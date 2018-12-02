require_relative "base"

module Wamp
  module Worker
    module Runner

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
    end
  end
end
