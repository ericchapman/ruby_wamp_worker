require_relative "base"

module Wamp
  module Worker
    module Proxy

      class Dispatcher < Base
        attr_accessor :session

        # We want to timeout every few seconds so higher level code can
        # look for a shutdown
        TIMEOUT = 2

        # Constructor
        #
        def initialize(name, session=nil, uuid: nil)
          super name, uuid: uuid
          self.session = session
        end

        # Increments the ticker
        #
        def increment_ticker
          self.ticker.increment(self.ticker_key)
        end

        # Check the queues
        #
        def check_queues
          check_queue [self.command_req_queue, self.background_res_queue]
        end

        # Executes the request
        #
        # @param request [Descriptor] - The request
        def process(descriptor)
          return unless descriptor != nil

          raise(RuntimeError, "must have a session to process a descriptor") unless self.session != nil

          # Create the callback
          callback = -> result, error, details {
            params = { result: result, error: error, details: details }
            self.queue.push descriptor.handle, descriptor.command, params
          }

          # Call the session
          if descriptor.command == :call

            # invoke the call method
            procedure = descriptor.params[:procedure]
            args = descriptor.params[:args]
            kwargs = descriptor.params[:kwargs]
            options = descriptor.params[:options]

            self.session.call(procedure, args, kwargs, options, &callback)

          elsif descriptor.command == :publish

            # invoke the publish method
            topic = descriptor.params[:topic]
            args = descriptor.params[:args]
            kwargs = descriptor.params[:kwargs]
            options = descriptor.params[:options]

            self.session.publish(topic,  args, kwargs, options, &callback)

          elsif descriptor.command == :yield

            # invoke the yield method
            request = descriptor.params[:request]
            options = descriptor.params[:options]
            check_defer = descriptor.params[:check_defer]
            result_hash = descriptor.params[:result] || {}
            result = Response.from_hash(result_hash)

            self.session.yield(request, result.object, options, check_defer)

          else

            # Return error if the command is not supported
            error = {
                error: "unsupported proxy command '#{descriptor.command}'",
                args: descriptor.params[:args],
                kwargs: descriptor.params[:kwargs],
            }
            callback.call(nil, error, nil)

          end

        end

        private

        # This methods blocks waiting for a value to appear in the queue
        #
        # @param queue_name [String] - the name of the queue
        def check_queue(queue_name)

          # Wait for a value to appear in the queue.  We have a timeout so
          # the thread can check if the worker has been killed
          self.queue.pop(queue_name, wait: true, timeout: TIMEOUT)
        end

      end
    end
  end
end

