# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Plain log entry for structured logging
    class Plain < T::Struct
      extend T::Sig

      include CommonInterface
      include SerializeCommon

      PlainLogEvent = T.type_alias {
        LogEvent::Log
      }

      # Common fields
      const :source, Source, default: T.let(Source::App, Source)
      const :event, PlainLogEvent, default: T.let(LogEvent::Log, PlainLogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Log message
      const :message, String

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        hash[LogKeys::MSG] = message
        hash
      end
    end
  end
end
