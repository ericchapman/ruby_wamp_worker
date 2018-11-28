require_relative "requestor"

module Wamp
  module Worker
    module Proxy

      class Backgrounder < Requestor
        attr_reader :handle

        # Constructor
        #
        def initialize(name, handle)
          super name
          @handle = handle
        end

        # Returns the response to the dispatcher
        #
        def yield(request, result, options={}, check_defer=false)
          # Create the params
          params = { request: request, result: result, options: options, check_defer: check_defer }

          # Push to the worker who requested the result
          self.queue.push self.handle, :yield, params
        end

      end
    end
  end
end
