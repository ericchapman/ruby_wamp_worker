module Wamp
  module Worker
    module Rails

      # This method will load Rails
      #
      # @param environment [String] - The Rails environment
      # @param require [String] - The path to the Rails working directory or a file with requires
      def self.load_app(environment, require)
        ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment

        raise ArgumentError, "'#{require}' does not exist" unless File.exist?(require)

        if File.directory?(require)
          require 'rails'
          if ::Rails::VERSION::MAJOR < 5
            raise "only Rails version 5 and higher supported"
          else
            require File.expand_path("#{require}/config/environment.rb")
          end
        else
          require(require) || raise(ArgumentError, "no require file found at '#{require}'")
        end
      end

    end
  end
end