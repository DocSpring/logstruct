# typed: strict
# frozen_string_literal: true

require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Common interface that all log entry types must implement
    module LogInterface
      extend T::Helpers

      interface!

      # Common required fields for all log types
      sig { abstract.returns(LogSource) }
      def src
      end

      sig { abstract.returns(LogEvent) }
      def evt
      end

      sig { abstract.returns(Time) }
      def ts
      end

      sig { abstract.returns(LogLevel) }
      def lvl
      end

      # Convert the log entry to a hash for serialization
      sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
      end
    end
  end
end
