# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Storage log entry for structured logging (ActiveStorage)
    class Storage < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.zone.now })
      const :msg, T.nilable(String), default: nil

      # Storage-specific fields
      const :service, T.nilable(String), default: nil
      const :operation, T.nilable(String), default: nil
      const :key, T.nilable(String), default: nil
      const :checksum, T.nilable(String), default: nil
      const :byte_size, T.nilable(Integer), default: nil
      const :content_type, T.nilable(String), default: nil
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

        # Add Storage-specific fields if they're present
        hash[:service] = service if service
        hash[:operation] = operation if operation
        hash[:key] = key if key
        hash[:checksum] = checksum if checksum
        hash[:byte_size] = byte_size if byte_size
        hash[:content_type] = content_type if content_type
        hash[:metadata] = metadata if metadata
        hash[:duration] = duration if duration

        hash
      end
    end
  end
end
