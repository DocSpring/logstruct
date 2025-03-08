# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/level"

module LogStruct
  module Log
    # ActiveStorage log entry for structured logging
    class ActiveStorage < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include SerializeCommon

      # Define valid event types for ActiveStorage
      ActiveStorageLogEvent = T.type_alias {
        T.any(
          LogEvent::Upload,
          LogEvent::Download,
          LogEvent::Delete,
          LogEvent::Metadata,
          LogEvent::Exist,
          LogEvent::Stream,
          LogEvent::Url,
          LogEvent::Unknown
        )
      }

      # Common fields
      const :source, Source::Storage, default: T.let(Source::Storage, Source::Storage)
      const :event, ActiveStorageLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

      # ActiveStorage-specific fields
      const :operation, T.nilable(Symbol), default: nil
      const :storage, T.nilable(String), default: nil
      const :file_id, T.nilable(String), default: nil
      const :filename, T.nilable(String), default: nil
      const :mime_type, T.nilable(String), default: nil
      const :size, T.nilable(Integer), default: nil
      const :metadata, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :checksum, T.nilable(String), default: nil
      const :exist, T.nilable(T::Boolean), default: nil
      const :url, T.nilable(String), default: nil
      const :prefix, T.nilable(String), default: nil
      const :range, T.nilable(String), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)

        # Add ActiveStorage-specific fields - only include non-nil values
        hash[LOG_KEYS.fetch(:operation)] = operation if operation
        hash[LOG_KEYS.fetch(:storage)] = storage if storage
        hash[LOG_KEYS.fetch(:file_id)] = file_id if file_id
        hash[LOG_KEYS.fetch(:filename)] = filename if filename
        hash[LOG_KEYS.fetch(:mime_type)] = mime_type if mime_type
        hash[LOG_KEYS.fetch(:size)] = size if size
        hash[LOG_KEYS.fetch(:metadata)] = metadata if metadata
        hash[LOG_KEYS.fetch(:duration)] = duration if duration
        hash[LOG_KEYS.fetch(:checksum)] = checksum if checksum
        hash[LOG_KEYS.fetch(:exist)] = exist if !exist.nil?
        hash[LOG_KEYS.fetch(:url)] = url if url
        hash[LOG_KEYS.fetch(:prefix)] = prefix if prefix
        hash[LOG_KEYS.fetch(:range)] = range if range

        hash
      end
    end
  end
end
