# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Error log entry for structured logging
    class Error < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Error-specific fields
      const :err_class, T.nilable(String), default: nil
      const :err_msg, T.nilable(String), default: nil
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }

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
