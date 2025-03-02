# typed: strict
# frozen_string_literal: true

module LogStruct
  module LogEntries
    # Common interface that all log entry types must implement
    module LogEntryInterface
      extend T::Sig
      extend T::Helpers

      interface!

      # Common required fields for all log types
      sig { abstract.returns(LogStruct::LogSource) }
      def src
      end

      sig { abstract.returns(LogStruct::LogEvent) }
      def evt
      end

      sig { abstract.returns(Time) }
      def ts
      end

      sig { abstract.returns(T.nilable(String)) }
      def msg
      end

      # Convert the log entry to a hash for serialization
      sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
      end
    end
  end
end
