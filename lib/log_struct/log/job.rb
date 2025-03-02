# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Job log entry for structured logging
    class Job < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.zone.now })
      const :msg, T.nilable(String), default: nil

      # Job-specific fields
      const :job_id, T.nilable(String), default: nil
      const :job_class, T.nilable(String), default: nil
      const :queue, T.nilable(String), default: nil
      const :args, T.nilable(T::Array[T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :status, T.nilable(String), default: nil
      const :error, T.nilable(String), default: nil
      const :retry_count, T.nilable(Integer), default: nil
      const :scheduled_at, T.nilable(Time), default: nil
      const :enqueued_at, T.nilable(Time), default: nil

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
        hash[:queue] = queue if queue
        hash[:args] = args if args
        hash[:duration] = duration if duration
        hash[:status] = status if status
        hash[:error] = error if error
        hash[:retry_count] = retry_count if retry_count

        # Format time fields - need to check for nil first
        hash[:scheduled_at] = scheduled_at&.iso8601(3) if scheduled_at
        hash[:enqueued_at] = enqueued_at&.iso8601(3) if enqueued_at

        hash
      end
    end
  end
end
