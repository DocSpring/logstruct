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
    # Sidekiq log entry for structured logging
    class Sidekiq < T::Struct
      extend T::Sig

      include CommonInterface
      include SerializeCommon

      # Common fields
      const :source, LogSource, default: T.let(LogSource::Sidekiq, LogSource)
      const :event, LogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Sidekiq-specific fields
      const :process_id, T.nilable(Integer), default: nil
      const :thread_id, T.nilable(Integer), default: nil
      const :message, T.nilable(String), default: nil
      const :context, T.nilable(T::Hash[Symbol, T.untyped]), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        hash[LogKeys::MSG] = message if message

        # Add Sidekiq-specific fields if they're present
        hash[LogKeys::PID] = process_id if process_id
        hash[LogKeys::TID] = thread_id if thread_id
        hash[LogKeys::CTX] = context if context
        hash
      end
    end
  end
end
