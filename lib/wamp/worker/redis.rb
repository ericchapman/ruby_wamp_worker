require "json"

module Wamp
  module Worker
    module Redis

      class ValueAlreadyRead < RuntimeError
      end

      class WorkerNotResponding < RuntimeError
      end

      class ResponseTimeout < RuntimeError
      end

      # This class represents the payload that will be stored in Redis
      class Descriptor
        attr_reader :command, :handle, :params

        # Constructor
        #
        # @param command [Symbol] - The command for the descriptor
        # @param handle [String] - The handle representing the descriptor
        # @param params [Hash] - The params for the command
        def initialize(command, handle, params)
          @command = command.to_sym
          @handle = handle
          @params = params
        end

        # Create a Descriptor object from the json payload
        #
        # @param json_string [String] - The string from the Redis store
        # @return [Descriptor] - The instantiated descriptor
        def self.from_json(json_string)
          return unless json_string
          parsed = JSON.parse(json_string, :symbolize_names => true)
          self.new(parsed[:command], parsed[:handle], parsed[:params])
        end

        # Creates the json payload from the object
        #
        # @return [String] - The string that will go into the Redis store
        def to_json
          { command: self.command, handle: self.handle, params: self.params }.to_json
        end
      end

      # This class is used to abstract the connection between the different
      # servers and the worker.  The data structures used in redis are as
      # follows
      #
      #   - "wamp:<name>:tick" - A constantly incrementing variable that will tell
      #     the clients if the designated worker is alive
      #   - "wamp:<name>:commands" - A redis list acting as a queue for commands
      #     to get sent to the worker
      #
      # where "name" is the name of the worker (we will support multiple
      # workers being instantiated)
      #
      # When a command is submitted, a "handle" will be generated that will provide
      # the caller a way to listen for the response.  The handle will be of the format
      #
      #   - "wamp:<name>:response:<id>"
      #
      # where "id" is a code used to uniquely identify the response.  Note that at
      # startup, all of the remaining responses will be wiped (cleanup)
      class Queue
        attr_reader :redis, :name, :timeout

        IDLE_TIMEOUT = 100

        # Constructor
        #
        # @param redis [Redis] - Connection to a redis store
        # @param name [Symbol] - The name of the worker
        def initialize(redis, name)
          @redis = redis
          @name = name
          @timeout = Wamp::Worker::CONFIG.timeout
        end

        # Returns the tick key for the worker
        #
        # @return [String] - The key for the tick
        def get_tick_key
          "wamp:#{self.name}:tick"
        end

        # Returns the commands queue key for the worker
        #
        # @return [String] - The key for the commands list
        def get_commands_key
          "wamp:#{self.name}:commands"
        end

        # Returns a new handle
        #
        # @return [String] - The key for the new handle
        def get_new_handle
          "wamp:#{self.name}:response:#{SecureRandom.hex(12)}"
        end

        #region Request Handler

        # Pushes a request to the worker
        #
        # @param command [Symbol] - The type of command
        # @param params [Hash] - The arguments for the command
        # @return [String] - The handle that will be used to wait for the response
        def push_request(command, params)
          queue = self.get_commands_key
          handle = self.get_new_handle

          # Create the descriptor
          descriptor = Descriptor.new(command, handle, params)

          # Queue the command
          self.redis.lpush(queue, descriptor.to_json)

          # Return the handle to the caller
          handle
        end

        # Retrieves a request from the queue
        #
        # @return [Descriptor] - The next command to process
        def pop_request
          queue = self.get_commands_key

          # Retrieve the request
          request = self.redis.rpop(queue)

          # If there is a request, parse it and return it.  Else return nil
          if request
            Descriptor.from_json(request)
          else
            nil
          end
        end

        #endregion

        #region Response Handler

        # Pushes a response to the requestor
        #
        # @param command [Symbol] - The type of command
        # @param handle [String] - The handle that will be used to respond
        # @param params [Hash] - The arguments for the command
        def push_response(command, handle, params)

          # Create the descriptor
          descriptor = Descriptor.new(command, handle, params)

          # Send the descriptor to the Redis store
          self.redis.set(handle, descriptor.to_json, ex: 5)
        end


        # Waits for a response from the worker
        #
        # @param handle [String] - The handle that was returned when the push was made
        # @return [Hash] - The response from the request
        def pop_response(handle)

          # Initialize variables
          old_tick = self.get_tick
          idle_count = 0
          response = nil
          start_time = Time.now.to_i

          # Iterate until a timeout or the response is received
          while response == nil and idle_count < IDLE_TIMEOUT

            # Get the next tick
            new_tick = self.get_tick

            # Get the current time
            current_time = Time.now.to_i

            # If the handle exists then we have a response
            if self.redis.exists(handle)

              # Get the response
              response = self.redis.get(handle)

              # If the response is "false", raise an exception signalling it was already read
              unless response
                raise ValueAlreadyRead.new("Value was already retrieved")
              end

              # Set the handle to "false" signalling that the response has already been fetched.
              # Also set it to auto delete in 5 seconds.  this gives us some time to throw an
              # exception signalling it was already read
              self.redis.set(handle, false, ex: 5)

            elsif current_time >= (start_time + self.timeout)

              # If we surpassed the overall timeout, trigger error
              raise ResponseTimeout.new("no response received after #{self.timeout} seconds")

            elsif new_tick == old_tick

              # If the tick hasn't moved, increment the timeout counter
              idle_count += 1

            else

              # Else the tick increased, reset the timeout
              old_tick = new_tick
              idle_count = 0
            end
          end

          # If a timeout was reached, throw the exception
          if idle_count >= IDLE_TIMEOUT
            raise WorkerNotResponding.new("Worker '#{self.name}' is not responding")
          end

          # Return the parsed descriptor
          Descriptor.from_json(response)
        end

        #endregion

        #region Tick Handler

        # Returns the tick for the worker
        #
        # @return [Int] - The value of the tick
        def get_tick
          self.redis.get(self.get_tick_key) || 0
        end

        # Increments the tick
        #
        def increment_tick
          self.redis.incr(self.get_tick_key)
        end

        #endregion

      end

    end
  end
end

