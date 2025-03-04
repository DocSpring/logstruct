# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Error log entry for general error logging (not tied to Ruby exceptions)
    class Error < T::Struct
      include LogInterface
      include LogSerialization

      # Common fields
      const :src, LogSource # Used by all sources, should not have a default.
      const :evt, LogEvent
      const :timestamp, Time, name: :ts, factory: -> { Time.now }
      const :level, LogLevel, name: :lvl, default: T.let(LogLevel::Error, LogLevel)

      # Error-specific fields
      const :msg, String
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add error-specific fields
        hash[:msg] = msg

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
