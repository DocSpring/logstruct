# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/data_field"
require_relative "interfaces/message_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Error log entry for general error logging (not related to Ruby exceptions)
    class Error < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::DataField
      include Interfaces::MessageField
      include SerializeCommon
      include MergeDataFields

      ErrorLogEvent = T.type_alias {
        LogEvent::Error
      }

      # Common fields
      const :source, Source # Used by all sources, should not have a default.
      const :event, ErrorLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Error, LogLevel)

      # Error-specific fields
      const :message, String
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize_log(strict = true)
        hash = serialize_common(strict)
        merge_data_fields(hash)

        # Add error-specific fields
        hash[LogKeys::MSG] = message

        hash
      end
    end
  end
end
