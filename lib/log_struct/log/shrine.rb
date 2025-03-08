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
    # Shrine log entry for structured logging
    class Shrine < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
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
      const :source, Source::Shrine, default: T.let(Source::Shrine, Source::Shrine)
      const :event, ShrineLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

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
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)

        # Add Shrine-specific fields if they're present
        hash[LOG_KEYS.fetch(:storage)] = storage if storage
        hash[LOG_KEYS.fetch(:location)] = location if location
        hash[LOG_KEYS.fetch(:upload_options)] = upload_options if upload_options
        hash[LOG_KEYS.fetch(:download_options)] = download_options if download_options
        hash[LOG_KEYS.fetch(:options)] = options if options
        hash[LOG_KEYS.fetch(:uploader)] = uploader if uploader
        hash[LOG_KEYS.fetch(:duration)] = duration if duration

        hash
      end
    end
  end
end
