# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"
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

      CarrierWaveEvent = T.type_alias {
        T.any(
          Event::Upload,
          Event::Download,
          Event::Delete,
          Event::Metadata,
          Event::Exist,
          Event::Unknown
        )
      }

      # Common fields
      const :source, Source::CarrierWave, default: T.let(Source::CarrierWave, Source::CarrierWave)
      const :event, CarrierWaveEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

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
        hash[LOG_KEYS.fetch(:storage)] = storage if storage
        hash[LOG_KEYS.fetch(:operation)] = operation if operation
        hash[LOG_KEYS.fetch(:file_id)] = file_id if file_id
        hash[LOG_KEYS.fetch(:filename)] = filename if filename
        hash[LOG_KEYS.fetch(:mime_type)] = mime_type if mime_type
        hash[LOG_KEYS.fetch(:size)] = size if size
        hash[LOG_KEYS.fetch(:metadata)] = metadata if metadata
        hash[LOG_KEYS.fetch(:duration)] = duration if duration

        # Add CarrierWave-specific fields if they're present
        hash[LOG_KEYS.fetch(:uploader)] = uploader if uploader
        hash[LOG_KEYS.fetch(:model)] = model if model
        hash[LOG_KEYS.fetch(:mount_point)] = mount_point if mount_point

        hash
      end
    end
  end
end
