# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module RailsStructuredLogging
  module LogEntries
    # Job log entry for structured logging
    class Job < T::Struct
      include LogEntryInterface

      # Common fields
      const :src, RailsStructuredLogging::LogSource
      const :evt, RailsStructuredLogging::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Job-specific fields
      const :job_id, T.nilable(String), default: nil
      const :job_class, T.nilable(String), default: nil
      const :queue, T.nilable(String), default: nil
      const :args, T.nilable(T::Array[T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :status, T.nilable(String), default: nil
      const :error, T.nilable(String), default: nil
      const :retry_count, T.nilable(Integer), default: nil
      const :scheduled_at, T.nilable(Time), default: nil
      const :enqueued_at, T.nilable(Time), default: nil
    end
  end
end
