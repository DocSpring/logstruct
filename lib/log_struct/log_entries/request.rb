# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module LogEntries
    # Request log entry for structured logging
    class Request < T::Struct
      include LogEntryInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Request-specific fields
      const :method, T.nilable(String), default: nil
      const :path, T.nilable(String), default: nil
      const :format, T.nilable(String), default: nil
      const :controller, T.nilable(String), default: nil
      const :action, T.nilable(String), default: nil
      const :status, T.nilable(Integer), default: nil
      const :duration, T.nilable(Float), default: nil
      const :view, T.nilable(Float), default: nil
      const :db, T.nilable(Float), default: nil
      const :ip, T.nilable(String), default: nil
      const :params, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :headers, T.nilable(T::Hash[String, T.untyped]), default: nil
    end
  end
end
