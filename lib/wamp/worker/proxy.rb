module Wamp
  module Worker
    module Proxy

      # This class serves as a proxy for the requestor to access the session
      class Session
        attr_reader :requestor

        # Constructor
        #
        # @param requestor [Wamp::Worker::Redis::Requestor] - The requestor
        def initialize(requestor)
          @requestor = requestor
        end

        # Performs the session "call" method
        def call(procedure, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { procedure: procedure, args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :call, params, &callback
        end

        # Performs the session "publish" method
        def publish(topic, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { topic: topic , args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :publish, params, &callback
        end

        private

        # Method to push the request and wait for the response
        def execute(command, params)

          # Push the request
          handle = self.requestor.push_request command, params

          # Wait for the response
          descriptor = self.requestor.pop_response(handle)

          # Return the values
          if block_given?
            response = [descriptor.params[:result], descriptor.params[:error], descriptor.params[:details]]
            yield(*response)
          end
        end


      end

      # This class serves as a proxy for the dispatcher to receive commands
      # from the requestor and return the results
      class Worker
        attr_reader :dispatcher
        attr_accessor :session

        # Constructor
        #
        # @param dispatcher [Wamp::Worker::Redis::dispatcher] - The dispatcher
        # @param session [Wamp::Client::Session] - The session for making the call
        def initialize(dispatcher, session=nil)
          @dispatcher = dispatcher
          @session = session
        end

        # Processes the pending requests that are in the queue
        def process_requests
          # Increment the ticker
          self.dispatcher.increment_tick

          # Exit if there is no session.  This will keep the items pending until
          # the session is re-established
          return unless self.session

          # Clear out the request queue
          request = self.dispatcher.pop_request
          while request

            # Create the callback
            callback = -> result, error, details {
              params = { result: result, error: error, details: details }
              self.dispatcher.push_response request.command, request.handle, params
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

            # Check for the next request
            request = self.dispatcher.pop_request
          end
        end

      end
    end

  end
end
