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
      const :src, LogSource, default: T.let(LogSource::Rails, LogSource)
      const :evt, LogEvent, default: T.let(LogEvent::Log, LogEvent)
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
