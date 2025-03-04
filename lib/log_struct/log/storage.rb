# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Storage log entry for structured logging
    class Storage < T::Struct
      include LogInterface
      include LogSerialization
      # Common fields
      const :source, LogSource, name: :src, default: T.let(LogSource::Storage, LogSource)
      const :evt, LogEvent
      const :timestamp, Time, name: :ts, factory: -> { Time.now }
      const :level, LogLevel, name: :lvl, default: T.let(LogLevel::Info, LogLevel)

      # File-specific fields
      const :storage, T.nilable(String), default: nil
      const :operation, T.nilable(String), default: nil
      const :file_id, T.nilable(String), default: nil
      const :filename, T.nilable(String), default: nil
      const :mime_type, T.nilable(String), default: nil
      const :size, T.nilable(Integer), default: nil
      const :metadata, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add file-specific fields if they're present
        hash[:storage] = storage if storage
        hash[:operation] = operation if operation
        hash[:file_id] = file_id if file_id
        hash[:filename] = filename if filename
        hash[:mime_type] = mime_type if mime_type
        hash[:size] = size if size
        hash[:metadata] = metadata if metadata
        hash[:duration] = duration if duration

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
