# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Notification log entry for structured logging
    class Notification < T::Struct
      include LogInterface
      include LogSerialization
      # Common fields
      const :src, LogSource, default: T.let(LogSource::App, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :msg, T.nilable(String), default: nil

      # Notification-specific fields
      const :name, T.nilable(String), default: nil
      const :type, T.nilable(String), default: nil
      const :duration, T.nilable(Float), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add notification-specific fields if they're present
        hash[:name] = name if name
        hash[:type] = type if type
        hash[:duration] = duration if duration

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
