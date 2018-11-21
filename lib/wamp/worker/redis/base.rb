module Wamp
  module Worker
    module Redis

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
      class Base
        attr_reader :redis, :name

        # Constructor
        #
        # @param name [Symbol] - The name of the worker
        # @param redis [Redis] - Connection to a redis store
        def initialize(name, redis)
          @name = name
          @redis = redis
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
      end
    end
  end
end

