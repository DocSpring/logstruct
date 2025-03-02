# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    # Common interface that all log entry types must implement
    module LogInterface
      extend T::Sig
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

      # Convert the log entry to a hash for serialization
      sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
      end
    end
  end
end
