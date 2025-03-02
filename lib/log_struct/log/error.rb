# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Error log entry for structured logging
    class Error < T::Struct
      include LogInterface
      include LogSerialization
      # Common fields
      const :src, LogSource # Used by all sources, should not have a default.
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :msg, T.nilable(String), default: nil

      # Error-specific fields
      const :err_class, T.nilable(String), default: nil
      const :err_msg, T.nilable(String), default: nil
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add error-specific fields if they're present
        hash[:err_class] = err_class if err_class
        hash[:err_msg] = err_msg if err_msg
        hash[:backtrace] = backtrace if backtrace

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
