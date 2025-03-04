# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Plain log entry for structured logging
    class Plain < T::Struct
      include LogInterface
      include LogSerialization
      # Common fields
      const :source, LogSource, name: :src, default: T.let(LogSource::Rails, LogSource)
      const :event, LogEvent, name: :evt, default: T.let(LogEvent::Log, LogEvent)
      const :timestamp, Time, name: :ts, factory: -> { Time.now }
      const :level, LogLevel, name: :lvl, default: T.let(LogLevel::Info, LogLevel)

      # Log message
      const :msg, String

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        common_serialize.merge(msg: msg)
      end
    end
  end
end
