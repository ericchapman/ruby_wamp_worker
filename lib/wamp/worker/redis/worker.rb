require_relative "base"

module Wamp
  module Worker
    module Redis

      # This class is used for the worker to communicate with the remote via redis
      class Worker < Base

        # Returns a request from the remote
        #
        def get_request
          queue = self.get_commands_key

          # Retrieve the request
          request = self.redis.rpop(queue)

          # If there is a request, parse it and return it.  Else return nil
          if request
            JSON.parse(request)
          else
            nil
          end
        end

        # Increments the tick
        #
        def increment_tick
          self.redis.incr(self.get_tick_key)
        end
      end
    end
  end
end

