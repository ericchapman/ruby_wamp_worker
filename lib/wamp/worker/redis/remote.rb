require_relative "base"
require "json"

module Wamp
  module Worker
    module Redis

      # This class is used for the remote to communicate with the worker via redis
      class Remote < Base

        # Pushes a request to the worker
        #
        # @param command [Symbol] - The type of command
        # @param args [Hash] - The arguments for the command
        # @return [String] - The handle that will be used to wait for the response
        def send_request(command, args)
          queue = self.get_commands_key
          handle = self.get_new_handle

          # Queue the command
          self.redis.lpush(queue, { command: command, handle: handle, args: args }.to_json)

          # Return the handle to the caller
          handle
        end

        # Waits for a response from the worker
        #
        # @param handle [String] - The handle that was returned when the push was made
        # @return [Hash] - The response from the request
        def wait_response(handle)
          # Initialize variables
          tick = self.get_tick
          timeout = 0
          response = nil

          # Iterate until a timeout or the response is received
          while response == nil and timeout < 100

            # Get the next tick
            new_tick = self.get_tick

            if self.redis.exists(handle)

              # If the handle exists then we have a response
              response = self.redis.get(handle)
              self.redis.delete(handle)

            elsif new_tick == tick

              # If the tick hasn't moved, increment the timeout counter
              timeout += 1

            else

              # Else the tick increased, reset the timeout
              tick = new_tick
              timeout = 0

            end
          end

          # If a timeout was reached, throw the exception
          if timeout == 100
            raise Exception.new("Worker #{self.name} is idle")
          end

          response
        end

        # Performs the request and waits for hte response
        #
        # @param command [Symbol] - The type of command
        # @param args [Hash] - The arguments for the command
        # @return [Hash] - The response from the request
        def call(command, args)
          # Make the request
          handle = self.send_request command, args

          # Wait for the response
          self.wait_response handle
        end

        # Returns the tick for the worker
        #
        # @return [Int] - The value of the tick
        def get_tick
          self.redis.get(self.get_tick_key)
        end

      end
    end
  end
end