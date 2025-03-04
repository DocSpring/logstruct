# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "interfaces/data_interface"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Email log entry for structured logging
    class Email < T::Struct
      extend T::Sig

      include CommonInterface
      include DataInterface
      include SerializeCommon
      include MergeDataFields

      # Common fields
      const :source, LogSource, default: T.let(LogSource::Mailer, LogSource)
      const :event, LogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Email-specific fields
      const :to, T.nilable(T.any(String, T::Array[String])), default: nil
      const :from, T.nilable(String), default: nil
      const :subject, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        merge_data_fields(hash)

        # Add email-specific fields if they're present
        hash[LogKeys::TO] = to if to
        hash[LogKeys::FROM] = from if from
        hash[LogKeys::SUBJECT] = subject if subject

        hash
      end
    end
  end
end
