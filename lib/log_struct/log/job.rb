# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Job log entry for structured logging
    class Job < T::Struct
      include LogInterface
      include LogSerialization

      # Common fields
      const :source, LogSource, name: :src, default: T.let(LogSource::Job, LogSource)
      const :event, LogEvent, name: :evt
      const :timestamp, Time, name: :ts, factory: -> { Time.now }
      const :level, LogLevel, name: :lvl, default: T.let(LogLevel::Info, LogLevel)

      # Job-specific fields
      const :job_id, T.nilable(String), default: nil
      const :job_class, T.nilable(String), default: nil
      const :queue_name, T.nilable(String), default: nil
      const :arguments, T.nilable(T::Array[T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add job-specific fields if they're present
        hash[:job_id] = job_id if job_id
        hash[:job_class] = job_class if job_class
        hash[:queue_name] = queue_name if queue_name
        hash[:arguments] = arguments if arguments
        hash[:duration] = duration if duration

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
