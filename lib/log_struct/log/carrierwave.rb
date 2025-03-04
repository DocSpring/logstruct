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
    # CarrierWave log entry for structured logging
    class CarrierWave < T::Struct
      extend T::Sig

      include CommonInterface
      include DataInterface
      include SerializeCommon
      include MergeDataFields

      # Common fields
      const :source, LogSource, default: T.let(LogSource::CarrierWave, LogSource)
      const :event, LogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # File-specific fields
      const :storage, T.nilable(String), default: nil
      const :operation, T.nilable(String), default: nil
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
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        merge_data_fields(hash)

        # Add file-specific fields if they're present
        hash[LogKeys::STORAGE] = storage if storage
        hash[LogKeys::OPERATION] = operation if operation
        hash[LogKeys::FILE_ID] = file_id if file_id
        hash[LogKeys::FILENAME] = filename if filename
        hash[LogKeys::MIME_TYPE] = mime_type if mime_type
        hash[LogKeys::SIZE] = size if size
        hash[LogKeys::METADATA] = metadata if metadata
        hash[LogKeys::DURATION] = duration if duration

        # Add CarrierWave-specific fields if they're present
        hash[LogKeys::UPLOADER] = uploader if uploader
        hash[LogKeys::MODEL] = model if model
        hash[LogKeys::MOUNT_POINT] = mount_point if mount_point

        hash
      end
    end
  end
end
