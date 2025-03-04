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
    # Shrine log entry for structured logging
    class Shrine < T::Struct
      extend T::Sig

      include CommonInterface
      include SerializeCommon

      ShrineLogEvent = T.type_alias {
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
      const :source, Source, default: T.let(Source::Shrine, Source)
      const :event, ShrineLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)
      const :msg, T.nilable(String), default: nil

      # Shrine-specific fields
      const :storage, T.nilable(String), default: nil
      const :location, T.nilable(String), default: nil
      const :upload_options, T.nilable(T::Hash[Symbol, T.untyped]), default: nil
      const :download_options, T.nilable(T::Hash[Symbol, T.untyped]), default: nil
      const :options, T.nilable(T::Hash[Symbol, T.untyped]), default: nil
      const :uploader, T.nilable(String), default: nil
      const :duration, T.nilable(Float), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        hash[LogKeys::MSG] = msg if msg

        # Add Shrine-specific fields if they're present
        hash[LogKeys::STORAGE] = storage if storage
        hash[LogKeys::LOCATION] = location if location
        hash[LogKeys::UPLOAD_OPTIONS] = upload_options if upload_options
        hash[LogKeys::DOWNLOAD_OPTIONS] = download_options if download_options
        hash[LogKeys::OPTIONS] = options if options
        hash[LogKeys::UPLOADER] = uploader if uploader
        hash[LogKeys::DURATION] = duration if duration

        hash
      end
    end
  end
end
