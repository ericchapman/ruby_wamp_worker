module Wamp
  module Worker
    module Error

      class HandleTypeError < TypeError
      end

      class ValueAlreadyRead < RuntimeError
      end

      class WorkerNotResponding < RuntimeError
      end

      class ResponseTimeout < RuntimeError
      end

      class ChallengeMissing < RuntimeError
      end

      class UndefinedConfiguration < RuntimeError
      end

    end
  end
end