# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module LogEntries
    # Notification log entry for structured logging
    class Notification < T::Struct
      include LogEntryInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Notification-specific fields
      const :name, T.nilable(String), default: nil
      const :type, T.nilable(String), default: nil
      const :duration, T.nilable(Float), default: nil
      const :data, T.nilable(T::Hash[Symbol, T.untyped]), default: {}
    end
  end
end
