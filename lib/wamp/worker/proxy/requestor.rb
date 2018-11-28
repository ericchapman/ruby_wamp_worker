require_relative "base"

module Wamp
  module Worker
    module Proxy

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
          request_response :call, params, true, &callback
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
          request_response :publish, params, options[:acknowledge], &callback
        end

        private

        # Method to push the request and wait for the response
        #
        # @param command [Symbol] - The command
        # @param params [Hash] - The parameters
        # @param wait [Bool] - if true, will wait for the response
        def request_response(command, params, wait=true)

          # Create a response handle
          handle = self.unique_command_resp_queue

          # Push the request
          self.queue.push self.command_req_queue, command, params, handle

          # If wait, check the queue and respond
          if wait

            # Store the start ticker
            start_tick = self.ticker.get(self.ticker_key)

            # Wait for the response
            descriptor = self.queue.pop(handle, wait: true, delete: true)

            # check for nil descriptor
            if descriptor == nil

              # If the ticker never incremented, throw a "worker not responding" error
              current_tick = self.ticker.get(self.ticker_key)
              if start_tick == current_tick
                raise Wamp::Worker::Error::WorkerNotResponding.new("worker '#{self.name}' is not responding")
              else
                raise Wamp::Worker::Error::ResponseTimeout.new("request to #{handle} timed out")
              end

            else

              # If a block was given, respond
              if block_given?
                response = [descriptor.params[:result], descriptor.params[:error], descriptor.params[:details]]
                yield(*response)
              end

            end

          end
        end


      end
    end
  end
end
