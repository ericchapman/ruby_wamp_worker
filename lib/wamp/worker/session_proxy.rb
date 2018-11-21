module Wamp
  module Worker

    # This class is meant to behave like a session
    class SessionProxy
      attr_reader :remote

      # Constructor
      #
      # @param remote [Wamp::Worker::Redis::Remote] - The remote handler
      def initialize(remote)
        @remote = remote
      end

      # Performs the session "call" method
      def call(procedure, args=nil, kwargs=nil, options={})
        args = { procedure: procedure, args: args, kwargs: kwargs, options: options }
        response = self.remote.call(:call, args)
        if block_given?
          yield(response[:result], response[:error], response[:details])
        end
      end

      # Performs the session "publish" method
      def publish(topic, args=nil, kwargs=nil, options={})
        args = { topic: topic , args: args, kwargs: kwargs, options: options }
        response = self.remote.call(:publish, args)
        if block_given?
          yield(response[:result], response[:error], response[:details])
        end
      end

    end
  end
end
