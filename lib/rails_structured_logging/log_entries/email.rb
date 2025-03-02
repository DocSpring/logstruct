# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module RailsStructuredLogging
  module LogEntries
    # Email log entry for structured logging
    class Email < T::Struct
      include LogEntryInterface

      # Common fields
      const :src, RailsStructuredLogging::LogSource
      const :evt, RailsStructuredLogging::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Email-specific fields
      const :msg_id, T.nilable(String), default: nil
      const :mailer, T.nilable(String), default: nil
      const :action, T.nilable(String), default: nil
      const :to, T.nilable(String), default: nil
      const :cc, T.nilable(T.nilable(String)), default: nil
      const :bcc, T.nilable(T.nilable(String)), default: nil
      const :subject, T.nilable(String), default: nil
    end
  end
end
