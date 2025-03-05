# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Sidekiq log entry for structured logging
    class Sidekiq < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include SerializeCommon

      # Common fields
      const :source, Source::Sidekiq, default: T.let(Source::Sidekiq, Source::Sidekiq)
      const :event, LogEvent, default: T.let(LogEvent::Log, LogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Sidekiq-specific fields
      const :process_id, T.nilable(Integer), default: nil
      const :thread_id, T.nilable(T.any(Integer, String)), default: nil
      const :message, T.nilable(String), default: nil
      const :context, T.nilable(T::Hash[Symbol, T.untyped]), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)

        # Add Sidekiq-specific fields if they're present
        hash[LogKeys::MSG] = message if message
        hash[LogKeys::CTX] = context if context
        hash[LogKeys::PID] = process_id if process_id
        hash[LogKeys::TID] = thread_id if thread_id
        hash
      end
    end
  end
end
