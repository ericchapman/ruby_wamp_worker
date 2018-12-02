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
        def initialize(name, session=nil)
          super name
          self.session = session
        end

        # Increments the ticker
        #
        def increment_ticker
          self.ticker.increment(self.ticker_key)
        end

        # Check command queue
        #
        def check_command_queue
          check_queue self.command_req_queue
        end

        # Check background queue
        #
        def check_background_queue
          check_queue self.background_res_queue
        end

        private

        # This methods blocks waiting for a value to appear in the queue
        #
        # @param queue_name [String] - the name of the queue
        def check_queue(queue_name)

          # Exit if there is no session.  This will keep the items pending until
          # the session is re-established
          return unless self.session

          # Wait for a value to appear in the queue
          descriptor = self.queue.pop(queue_name, wait: true, timeout: TIMEOUT)

          # Execute the request if it exists
          execute_request descriptor if descriptor

        end

        # Executes the request
        #
        # @param request [Descriptor] - The request
        def execute_request(request)

          # Create the callback
          callback = -> result, error, details {
            params = { result: result, error: error, details: details }
            self.queue.push request.handle, request.command, params
          }

          # Call the session
          if request.command == :call

            # invoke the call method
            procedure = request.params[:procedure]
            args = request.params[:args]
            kwargs = request.params[:kwargs]
            options = request.params[:options]
            self.session.call(procedure, args, kwargs, options, &callback)

          elsif request.command == :publish

            # invoke the publish method
            topic = request.params[:topic]
            args = request.params[:args]
            kwargs = request.params[:kwargs]
            options = request.params[:options]
            self.session.publish(topic,  args, kwargs, options, &callback)

          elsif request.command == :yield

            # invoke the yield method
            req_id = request.params[:request]
            options = request.params[:options]
            check_defer = request.params[:check_defer]
            result_hash = request.params[:result] || {}

            # Parse the results for data or error
            result = Response.from_hash(result_hash)

            # CAll the yield method
            self.session.yield(req_id, result.object, options, check_defer)

          else

            # Return error if the command is not supported
            error = {
                error: "unsupported proxy command '#{request.command}'",
                args: request.params[:args],
                kwargs: request.params[:kwargs],
            }
            callback.call(nil, error, nil)

          end

        end

      end
    end
  end
end

