# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Email log entry for structured logging
    class Email < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::DataField
      include SerializeCommon
      include MergeDataFields

      EmailLogEvent = T.type_alias {
        T.any(LogEvent::Delivery, LogEvent::Delivered)
      }

      # Common fields
      const :source, Source, default: T.let(Source::Mailer, Source)
      const :event, EmailLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Email-specific fields
      const :to, T.nilable(T.any(String, T::Array[String])), default: nil
      const :from, T.nilable(String), default: nil
      const :subject, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize_log(strict = true)
        hash = serialize_common(strict)
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
