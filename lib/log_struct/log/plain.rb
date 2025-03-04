# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "shared/serialize_common"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Plain log entry for structured logging
    class Plain < T::Struct
      extend T::Sig

      include CommonInterface
      include SerializeCommon

      # Common fields
      const :source, LogSource, default: T.let(LogSource::Rails, LogSource)
      const :event, LogEvent, default: T.let(LogEvent::Log, LogEvent)
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
