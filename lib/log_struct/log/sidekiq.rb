# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Sidekiq log entry for structured logging
    class Sidekiq < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include SerializeCommon

      # Define valid event types for Sidekiq (currently only Log is used)
      SidekiqLogEvent = T.type_alias { LogEvent::Log }

      # Common fields
      const :source, Source::Sidekiq, default: T.let(Source::Sidekiq, Source::Sidekiq)
      const :event, SidekiqLogEvent, default: T.let(LogEvent::Log, SidekiqLogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

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
        hash[LOG_KEYS.fetch(:message)] = message if message
        hash[LOG_KEYS.fetch(:context)] = context if context
        hash[LOG_KEYS.fetch(:process_id)] = process_id if process_id
        hash[LOG_KEYS.fetch(:thread_id)] = thread_id if thread_id

        hash
      end
    end
  end
end
