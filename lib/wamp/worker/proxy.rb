require_relative "redis"

module Wamp
  module Worker
    module Proxy

      class Base
        attr_reader :queue

        def initialize(redis, name)
          @queue = Wamp::Worker::Redis::Queue.new(redis, name)
        end
      end

      # This class serves as a proxy for the requestor to access the session
      class Requestor < Base

        # Performs the session "call" method
        def call(procedure, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { procedure: procedure, args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :call, params, true, &callback
        end

        # Performs the session "publish" method
        def publish(topic, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { topic: topic , args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :publish, params, options[:acknowledge], &callback
        end

        private

        # Method to push the request and wait for the response
        def execute(command, params, wait=true)

          # Push the request
          handle = self.queue.push_request command, params

          if wait
            # Wait for the response
            descriptor = self.queue.pop_response(handle)

            # Return the values
            if block_given?
              response = [descriptor.params[:result], descriptor.params[:error], descriptor.params[:details]]
              yield(*response)
            end
          end
        end

      end

      # This class serves as a proxy for the dispatcher to receive commands
      # from the requestor and return the results
      class Dispatcher < Base
        attr_accessor :session

        # Constructor
        #
        def initialize(redis, name, session=nil)
          super redis, name
          self.session = session
        end

        # Processes the pending requests that are in the queue
        def process_requests

          # Increment the ticker
          self.queue.increment_tick

          # Exit if there is no session.  This will keep the items pending until
          # the session is re-established
          return unless self.session

          # Iterate through the requests
          loop do

            # Get the next request
            request = self.queue.pop_request

            # Break if there are no more requests
            break unless request

            # Create the callback
            callback = -> result, error, details {
              params = { result: result, error: error, details: details }
              self.queue.push_response request.command, request.handle, params
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
              self.session.publish(topic, args, kwargs, options, &callback)

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
end
