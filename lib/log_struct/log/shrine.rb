# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Shrine log entry for structured logging
    class Shrine < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.zone.now })
      const :msg, T.nilable(String), default: nil

      # File-specific fields
      const :storage, T.nilable(String), default: nil
      const :operation, T.nilable(String), default: nil
      const :file_id, T.nilable(String), default: nil
      const :filename, T.nilable(String), default: nil
      const :mime_type, T.nilable(String), default: nil
      const :size, T.nilable(Integer), default: nil
      const :metadata, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }

        # Add file-specific fields if they're present
        hash[:storage] = storage if storage
        hash[:operation] = operation if operation
        hash[:file_id] = file_id if file_id
        hash[:filename] = filename if filename
        hash[:mime_type] = mime_type if mime_type
        hash[:size] = size if size
        hash[:metadata] = metadata if metadata
        hash[:duration] = duration if duration

        hash
      end
    end
  end
end
