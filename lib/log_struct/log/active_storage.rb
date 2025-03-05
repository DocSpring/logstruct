# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"

module LogStruct
  module Log
    # ActiveStorage log entry for structured logging
    class ActiveStorage < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include SerializeCommon

      # Common fields
      const :source, Source::Storage, default: T.let(Source::Storage, Source::Storage)
      const :event, LogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

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
        hash[LogKeys::OP] = operation if operation
        hash[LogKeys::STORAGE] = storage if storage
        hash[LogKeys::FILE_ID] = file_id if file_id
        hash[LogKeys::FILENAME] = filename if filename
        hash[LogKeys::MIME_TYPE] = mime_type if mime_type
        hash[LogKeys::SIZE] = size if size
        hash[LogKeys::METADATA] = metadata if metadata
        hash[LogKeys::DURATION] = duration if duration
        hash[LogKeys::CHECKSUM] = checksum if checksum
        hash[LogKeys::EXIST] = exist if !exist.nil?
        hash[LogKeys::URL] = url if url
        hash[LogKeys::PREFIX] = prefix if prefix
        hash[LogKeys::RANGE] = range if range

        hash
      end
    end
  end
end
