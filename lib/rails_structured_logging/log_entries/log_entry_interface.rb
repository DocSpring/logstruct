# typed: strict
# frozen_string_literal: true

module RailsStructuredLogging
  module LogEntries
    # Common interface that all log entry types must implement
    module LogEntryInterface
      extend T::Sig
      extend T::Helpers

      interface!

      # Common required fields for all log types
      sig { abstract.returns(RailsStructuredLogging::LogSource) }
      def src
      end

      sig { abstract.returns(RailsStructuredLogging::LogEvent) }
      def evt
      end

      sig { abstract.returns(Time) }
      def ts
      end

      sig { abstract.returns(T.nilable(String)) }
      def msg
      end
    end
  end
end
