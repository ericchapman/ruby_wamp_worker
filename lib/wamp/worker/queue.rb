require "json"

module Wamp
  module Worker

    class Queue
      attr_reader :redis, :default_timeout

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
          @params = params || {}
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

      # Constructor
      #
      def initialize(name)
        @redis = Wamp::Worker.config.redis(name)
        @default_timeout = Wamp::Worker.config.timeout(name)
      end

      # Pushes a command onto the queue
      #
      # @param queue_name [String] - The name of the queue
      # @param command [Symbol] - The command
      # @param params [Hash] - The params for the request
      # @param handle [String] - The response handle
      def push(queue_name, command, params, handle=nil)

        # Create the descriptor
        descriptor = Descriptor.new(command, handle, params)

        # Log the info
        log(:push, queue_name, descriptor)

        # Queue the command
        self.redis.lpush(queue_name, descriptor.to_json)
      end

      # Pops a command off of the queue
      #
      # @param queue_name [String] - The name of the queue
      # @param wait [Bool] - True if we want to block waiting for the response
      # @param delete [Bool] - True if we want the queue deleted (only applicable if wait)
      # @param timeout [Int] - Number of seconds to wait before timing out
      def pop(queue_name, wait: false, delete: false, timeout: nil)

        # Retrieve the response from the queue
        if wait
          # Use the default timeout if non is specified
          timeout ||= self.default_timeout

          # Make the pop call
          response = self.redis.brpop(queue_name, timeout: timeout)
        else
          # Else just call the method
          response = self.redis.rpop(queue_name)
        end

        # If delete was set, delete the queue
        if delete
          self.redis.delete(queue_name)
        end

        # Log the info

        # Parse the response
        descriptor = response != nil ? Descriptor.from_json(response) : nil

        # Log the info
        log(:pop, queue_name, descriptor)

        descriptor
      end

      private

      # Returns the logger
      #
      def logger
        Wamp::Worker.logger
      end

      # Logs the info
      #
      def log(type, queue_name, descriptor)
        return unless logger.level == Logger::DEBUG

        logger.debug("")

        if descriptor
          logger.debug("#{self.class.name} #{type.upcase} : #{queue_name}")
          logger.debug("   command: #{descriptor.command}")
          logger.debug("   params: #{descriptor.params}")
          logger.debug("   handle: #{descriptor.handle}")
        else
          logger.debug("#{self.class.name} #{type.upcase} : #{queue_name} : EMPTY")
        end
      end


    end
  end
end

