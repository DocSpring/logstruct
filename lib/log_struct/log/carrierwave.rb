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
    # CarrierWave log entry for structured logging
    class CarrierWave < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::DataField
      include SerializeCommon
      include MergeDataFields

      CarrierWaveLogEvent = T.type_alias {
        T.any(
          LogEvent::Upload,
          LogEvent::Download,
          LogEvent::Delete,
          LogEvent::Metadata,
          LogEvent::Exist,
          LogEvent::Unknown
        )
      }

      # Common fields
      const :source, Source, default: T.let(Source::CarrierWave, Source)
      const :event, CarrierWaveLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # File-specific fields
      const :operation, T.nilable(Symbol), default: nil
      const :storage, T.nilable(String), default: nil
      const :file_id, T.nilable(String), default: nil
      const :filename, T.nilable(String), default: nil
      const :mime_type, T.nilable(String), default: nil
      const :size, T.nilable(Integer), default: nil
      const :metadata, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil

      # CarrierWave-specific fields
      const :uploader, T.nilable(String), default: nil
      const :model, T.nilable(String), default: nil
      const :mount_point, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_data_fields(hash)

        # Add file-specific fields if they're present
        hash[LOG_KEYS[:storage]] = storage if storage
        hash[LOG_KEYS[:operation]] = operation if operation
        hash[LOG_KEYS[:file_id]] = file_id if file_id
        hash[LOG_KEYS[:filename]] = filename if filename
        hash[LOG_KEYS[:mime_type]] = mime_type if mime_type
        hash[LOG_KEYS[:size]] = size if size
        hash[LOG_KEYS[:metadata]] = metadata if metadata
        hash[LOG_KEYS[:duration]] = duration if duration

        # Add CarrierWave-specific fields if they're present
        hash[LOG_KEYS[:uploader]] = uploader if uploader
        hash[LOG_KEYS[:model]] = model if model
        hash[LOG_KEYS[:mount_point]] = mount_point if mount_point

        hash
      end
    end
  end
end
