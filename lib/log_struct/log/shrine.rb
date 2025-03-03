# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Shrine log entry for structured logging
    class Shrine < T::Struct
      include LogInterface
      include LogSerialization

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Shrine, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :lvl, LogLevel, default: T.let(LogLevel::Info, LogLevel)
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
        hash = common_serialize

        # Add message if present
        hash[:msg] = msg if msg

        # Add Shrine-specific fields if they're present
        hash[:storage] = storage if storage
        hash[:location] = location if location
        hash[:upload_options] = upload_options if upload_options
        hash[:download_options] = download_options if download_options
        hash[:options] = options if options
        hash[:uploader] = uploader if uploader
        hash[:duration] = duration if duration

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
