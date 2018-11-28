require_relative "../ticker"
require_relative "../queue"

module Wamp
  module Worker
    module Proxy

      class Base
        attr_reader :queue, :ticker, :name, :uuid

        # Constructor
        #
        # @param name [Symbol] - The name of the connection
        def initialize(name)
          @name = name
          @queue = Wamp::Worker::Queue.new(name)
          @ticker = Wamp::Worker::Ticker.new(name)
          @uuid = ENV['DYNO'] || SecureRandom.hex(12)
        end

        #region Command/Response
        # ----------------
        # This workflow is used by a "Requestor" to make a "call"
        # or "publish" request to the "Dispatcher".  This would for example be in
        # your rails app where a service or controller needs to make a WAMP call
        #
        # The flow is as follows
        #
        #  - Requestor performs a "push" operation with the following parameters
        #     - queue_name - The "command queue"
        #     - command - The command ("call" or "publish")
        #     - params - The parameters for the command (args/kwargs/etc.)
        #     - handle - A unique "response queue" name that the Dispatcher will
        #       provide the resposne on
        #  - Requestor then blocks (with timeout) awaiting the response
        #  - Dispatcher performs a "pop" operation and executes the command
        #  - Dispatcher "pushes" the response to the "handle" queue
        #  - Requestor "pops" the response and deletes the temporary "handle" queue

        # Returns the commands queue key for the worker
        #
        # @return [String] - The key for the commands list
        def command_req_queue
          "wamp:#{self.name}:command"
        end

        # Returns a new handle
        #
        # @return [String] - The key for the new handle
        def unique_command_resp_queue
          "wamp:#{self.name}:response:#{SecureRandom.hex(12)}"
        end

        #endregion

        #region Dispatcher/Backgrounder
        # ----------------
        # This workflow is used by a "Dispatcher" to execute a "topic" or "procedure"
        # on a background thread.  This is used by a "BackgroundHandler" to push a
        # handler to Sidekiq and get the response from the background job.  This frees
        # up the Event Machine to process other requests
        #
        # The flow is as follows
        #
        #  - Dispatcher pushes the task to the background sidekiq worker providing
        #    the "handle" it will respond on
        #  - Backgrounder performs the operation
        #  - Backgrounder performs a "push" with response back to the Dispatcher
        #  - Dispatcher performs a "pop" and sends the response (if it is a call)

        # Returns the response queue name for the backgrounder
        #
        # @return [String] - The key for the worker
        def background_res_queue
          "wamp:#{self.name}:background:#{self.uuid}"
        end

        #endregion

        #region Requestor/Dispatcher Ticker
        # ----------------
        # This workflow is used to sense when a worker is no longer running
        #
        # The flow is as follows
        #
        #  - Dispatcher periodically increments the ticker
        #  - Requestor does the following when performing a pop
        #     - stores the value of the ticker
        #     - blocks waiting for a "pop"
        #     - if the pop comes back "nil", it means we timed out
        #     - if the value of the ticker is that same as before, then th worker is not running

        # Returns the key for the ticker
        #
        # @return [String] - The key for the ticker
        def ticker_key
          "wamp:#{self.name}:tick"
        end
        #endregion

      end
    end
  end
end
