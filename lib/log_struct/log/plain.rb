# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Plain log entry for structured logging
    class Plain < T::Struct
      include LogInterface

      # Common fields
      const :msg, String
      const :src, LogStruct::LogSource, default: T.let(LogStruct::LogSource::Rails, LogStruct::LogSource)
      const :evt, LogStruct::LogEvent, default: T.let(LogStruct::LogEvent::Log, LogStruct::LogEvent)
      const :ts, Time, factory: -> { Time.now }

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }
      end
    end
  end
end
