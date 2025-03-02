# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module RailsStructuredLogging
  module LogEntries
    # Error log entry for structured logging
    class Error < T::Struct
      include LogEntryInterface

      # Common fields
      const :src, RailsStructuredLogging::LogSource
      const :evt, RailsStructuredLogging::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Error-specific fields
      const :err_class, T.nilable(String), default: nil
      const :err_msg, T.nilable(String), default: nil
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}
    end
  end
end
