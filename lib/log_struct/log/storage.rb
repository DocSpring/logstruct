# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"

module LogStruct
  module Log
    # Storage log entry for structured logging
    class Storage < T::Struct
      extend T::Sig

      include CommonInterface
      include SerializeCommon

      # Common fields
      const :source, Source, default: T.let(Source::Storage, Source)
      const :event, LogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Storage-specific fields
      const :operation, T.nilable(Symbol), default: nil
      const :storage, T.nilable(String), default: nil
      const :file_id, T.nilable(String), default: nil
      const :filename, T.nilable(String), default: nil
      const :mime_type, T.nilable(String), default: nil
      const :size, T.nilable(Integer), default: nil
      const :metadata, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil

      # ActiveStorage-specific fields
      const :checksum, T.nilable(String), default: nil
      const :exist, T.nilable(T::Boolean), default: nil
      const :url, T.nilable(String), default: nil
      const :prefix, T.nilable(String), default: nil
      const :range, T.nilable(String), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common

        # Add storage-specific fields
        hash[:storage] = storage if storage
        hash[:operation] = operation if operation
        hash[:file_id] = file_id if file_id
        hash[:filename] = filename if filename
        hash[:mime_type] = mime_type if mime_type
        hash[:size] = size if size
        hash[:metadata] = metadata if metadata
        hash[:duration] = duration if duration

        # Add ActiveStorage-specific fields
        hash[:checksum] = checksum if checksum
        hash[:exist] = exist if !exist.nil?
        hash[:url] = url if url
        hash[:prefix] = prefix if prefix
        hash[:range] = range if range

        hash
      end
    end
  end
end
