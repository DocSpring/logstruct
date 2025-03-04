# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "interfaces/data_interface"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Job log entry for structured logging
    class Job < T::Struct
      extend T::Sig

      include CommonInterface
      include DataInterface
      include SerializeCommon
      include MergeDataFields

      JobLogEvent = T.type_alias {
        T.any(
          LogEvent::Enqueue,
          LogEvent::Schedule,
          LogEvent::Start,
          LogEvent::Finish
        )
      }

      # Common fields
      const :source, Source, default: T.let(Source::Job, Source)
      const :event, JobLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

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
        hash = serialize_common
        merge_data_fields(hash)

        # Add job-specific fields if they're present
        hash[LogKeys::JOB_ID] = job_id if job_id
        hash[LogKeys::JOB_CLASS] = job_class if job_class
        hash[LogKeys::QUEUE_NAME] = queue_name if queue_name
        hash[LogKeys::ARGUMENTS] = arguments if arguments
        hash[LogKeys::DURATION] = duration if duration

        hash
      end
    end
  end
end
