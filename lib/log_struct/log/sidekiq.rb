# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Sidekiq log entry for structured logging
    class Sidekiq < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource, default: T.let(LogStruct::LogSource::Sidekiq, LogStruct::LogSource)
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.zone.now })
      const :msg, T.nilable(String), default: nil

      # Sidekiq-specific fields
      const :job_id, T.nilable(String), default: nil
      const :job_class, T.nilable(String), default: nil
      const :queue_name, T.nilable(String), default: nil
      const :arguments, T.nilable(T::Array[T.untyped]), default: nil
      const :duration, T.nilable(Float), default: nil
      const :retry_count, T.nilable(Integer), default: nil
      const :status, T.nilable(String), default: nil
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

        # Add Sidekiq-specific fields if they're present
        hash[:job_id] = job_id if job_id
        hash[:job_class] = job_class if job_class
        hash[:queue_name] = queue_name if queue_name
        hash[:arguments] = arguments if arguments
        hash[:duration] = duration if duration
        hash[:retry_count] = retry_count if retry_count
        hash[:status] = status if status

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
