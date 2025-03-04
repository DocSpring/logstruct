# typed: strict
# frozen_string_literal: true

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

      # Common fields (without event)
      const :source, Source::Sidekiq, default: T.let(Source::Sidekiq, Source::Sidekiq)
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
        {
          LogKeys::SRC => source.serialize,
          LogKeys::TS => timestamp.iso8601(3),
          LogKeys::LVL => level.serialize,
          LogKeys::MSG => message,
          LogKeys::PID => process_id,
          LogKeys::TID => thread_id,
          LogKeys::CTX => context
        }
      end
    end
  end
end
