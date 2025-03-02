# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Job log entry for structured logging
    class Job < T::Struct
      include LogInterface

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Job, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :msg, T.nilable(String), default: nil

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
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }

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
