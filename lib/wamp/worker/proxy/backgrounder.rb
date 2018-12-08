require_relative "requestor"

module Wamp
  module Worker
    module Proxy

      class Backgrounder < Requestor
        attr_reader :handle

        # Constructor
        #
        def initialize(name, handle, uuid: nil)
          super name, uuid: uuid
          @handle = handle
        end

        # Returns the response to the dispatcher
        #
        # @param request [Int] - The ID of the request
        # @param result [CallResult,CallError] - The result or error for us to serialize
        # @param options [Hash] - Options for the yield
        # @param check_defer [Bool] - 'true' is this is linked to a defer call
        def yield(request, result, options={}, check_defer=false)

          # Create the response object
          result = Wamp::Client::Response::CallResult.ensure(result, allow_error: true)

          # Create the params
          params = { request: request, result: result.to_hash, options: options, check_defer: check_defer }

          # Push to the worker who requested the result
          self.queue.push self.handle, :yield, params
        end

      end
    end
  end
end
