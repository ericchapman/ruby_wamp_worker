require_relative "redis"

module Wamp
  module Worker
    module Proxy

      class Base
        attr_reader :queue, :name

        # Constructor
        #
        # @param redis [Redis] - A redis instance
        # @param name [Symbol] - The name of the connection
        def initialize(redis, name)
          @name = name
          @queue = Wamp::Worker::Redis::Queue.new(redis, name)
        end

        # Method to push the request and wait for the response
        #
        # @param command [Symbol] - The command
        # @param params [Hash] - The parameters
        # @param wait [Bool] - if true, will wait for the response
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

      # This class serves as a proxy for the requestor to access the session
      #
      class Requestor < Base

        # Performs the session "call" method
        #
        # @param procedure [String] - The procedure to call
        # @param args [Array] - Array of arguments
        # @param kwargs [Hash] - Hash of key/word arguments
        # @param options [Hash] - Options for the call
        def call(procedure, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { procedure: procedure, args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :call, params, true, &callback
        end

        # Performs the session "publish" method
        #
        # @param topic [String] - The topic to publish
        # @param args [Array] - Array of arguments
        # @param kwargs [Hash] - Hash of key/word arguments
        # @param options [Hash] - Options for the subscribe
        def publish(topic, args=nil, kwargs=nil, options={}, &callback)

          # Create the params
          params = { topic: topic , args: args, kwargs: kwargs, options: options }

          # Execute the command
          execute :publish, params, options[:acknowledge], &callback
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

        # Executes the request
        #
        # @param request [Descriptor] - The request
        def execute_request(request)

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
            self.session.publish(topic,  args, kwargs, options, &callback)

          elsif request.command == :yield

            # invoke the yield method
            req_id = request.params[:request]
            options = request.params[:options]
            check_defer = request.params[:check_defer]

            # Parse the results for data or error
            result = nil
            if request.params[:result] != nil
              temp = request.params[:result]
              result = Wamp::Client::CallResult.new(temp[:args], temp[:kwargs])
            elsif request.params[:error]
              temp = request.params[:error]
              result = Wamp::Client::CallError.new(temp[:error], temp[:args], temp[:kwargs])
            end

            # CAll the yield method
            self.session.yield(req_id, result, options, check_defer)

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

        # Processes the pending requests that are in the queue
        #
        def process_requests

          # Increment the ticker
          self.queue.increment_tick

          # Exit if there is no session.  This will keep the items pending until
          # the session is re-established
          return unless self.session

          # Create the pop loop
          pop_loop = -> pop_method {
              loop do

                # Get the next request
                request = pop_method.call

                # Break if there are no more requests
                break unless request

                # Execute the request
                self.execute_request request
              end
          }

          # Check the normal requests
          pop_loop.call -> { self.queue.pop_request }

          # Check the background responses
          pop_loop.call -> { self.queue.pop_background }
        end

      end
    end

  end
end
