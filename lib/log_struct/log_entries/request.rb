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

        # Add request-specific fields if they're present
        hash[:method] = method if method
        hash[:path] = path if path
        hash[:format] = format if format
        hash[:controller] = controller if controller
        hash[:action] = action if action
        hash[:status] = status if status
        hash[:duration] = duration if duration
        hash[:view] = view if view
        hash[:db] = db if db
        hash[:ip] = ip if ip
        hash[:params] = params if params
        hash[:headers] = headers if headers

        hash
      end
    end
  end
end
