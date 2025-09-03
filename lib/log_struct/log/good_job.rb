# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/additional_data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_additional_data_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"
require_relative "../log_keys"

module LogStruct
  module Log
    # GoodJob log entry for structured logging
    #
    # GoodJob is a PostgreSQL-based ActiveJob backend that provides reliable,
    # scalable job processing for Rails applications. This log class captures
    # GoodJob-specific events including job execution, database operations,
    # error handling, and performance metrics.
    #
    # ## Key Features Logged:
    # - Job execution lifecycle (enqueue, start, finish, retry)
    # - Database-backed job persistence events
    # - Error handling and retry logic
    # - Job batching and bulk operations
    # - Performance metrics and timing data
    # - Thread and process information
    #
    # ## Usage Examples:
    #
    # ```ruby
    # # Job execution logging
    # LogStruct::Log::GoodJob.new(
    #   event: Event::Start,
    #   job_id: "job_123",
    #   job_class: "UserNotificationJob",
    #   queue_name: "default",
    #   execution_time: 1.5
    # )
    #
    # # Error logging
    # LogStruct::Log::GoodJob.new(
    #   event: Event::Error,
    #   job_id: "job_123",
    #   error_class: "StandardError",
    #   error_message: "Connection failed"
    # )
    # ```
    class GoodJob < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      # Valid event types for GoodJob operations
      GoodJobEvent = T.type_alias {
        T.any(
          Event::Log,         # General logging
          Event::Enqueue,     # Job queued
          Event::Start,       # Job execution started
          Event::Finish,      # Job completed successfully
          Event::Error,       # Job failed with error
          Event::Schedule     # Job scheduled for future execution
        )
      }

      # Common fields
      const :source, Source::Job, default: T.let(Source::Job, Source::Job)
      const :event, GoodJobEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

      # Job identification fields
      const :job_id, T.nilable(String), default: nil
      const :job_class, T.nilable(String), default: nil
      const :queue_name, T.nilable(String), default: nil
      const :batch_id, T.nilable(String), default: nil
      const :job_label, T.nilable(String), default: nil

      # Job execution context
      const :arguments, T.nilable(T::Array[T.untyped]), default: nil
      const :executions, T.nilable(Integer), default: nil
      const :exception_executions, T.nilable(Integer), default: nil
      const :execution_time, T.nilable(Float), default: nil
      const :scheduled_at, T.nilable(Time), default: nil

      # Error information
      const :error_class, T.nilable(String), default: nil
      const :error_message, T.nilable(String), default: nil
      const :error_backtrace, T.nilable(T::Array[String]), default: nil

      # GoodJob-specific metadata
      const :process_id, T.nilable(Integer), default: nil
      const :thread_id, T.nilable(String), default: nil
      const :priority, T.nilable(Integer), default: nil
      const :cron_key, T.nilable(String), default: nil
      const :database_connection_name, T.nilable(String), default: nil

      # Performance and metrics
      const :wait_time, T.nilable(Float), default: nil
      const :run_time, T.nilable(Float), default: nil
      const :finished_at, T.nilable(Time), default: nil

      # Additional contextual data
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)

        # Add job identification fields
        hash[LOG_KEYS.fetch(:job_id)] = job_id if job_id
        hash[LOG_KEYS.fetch(:job_class)] = job_class if job_class
        hash[LOG_KEYS.fetch(:queue_name)] = queue_name if queue_name
        hash[:batch_id] = batch_id if batch_id
        hash[:job_label] = job_label if job_label

        # Add execution context
        hash[LOG_KEYS.fetch(:arguments)] = arguments if arguments
        hash[:executions] = executions if executions
        hash[:exception_executions] = exception_executions if exception_executions
        hash[:execution_time] = execution_time if execution_time
        hash[:scheduled_at] = scheduled_at&.iso8601 if scheduled_at

        # Add error information
        hash[LOG_KEYS.fetch(:err_class)] = error_class if error_class
        hash[:error_message] = error_message if error_message
        hash[LOG_KEYS.fetch(:backtrace)] = error_backtrace if error_backtrace

        # Add GoodJob-specific metadata
        hash[LOG_KEYS.fetch(:process_id)] = process_id if process_id
        hash[LOG_KEYS.fetch(:thread_id)] = thread_id if thread_id
        hash[:priority] = priority if priority
        hash[:cron_key] = cron_key if cron_key
        hash[:database_connection_name] = database_connection_name if database_connection_name

        # Add performance metrics
        hash[:wait_time] = wait_time if wait_time
        hash[:run_time] = run_time if run_time
        hash[:finished_at] = finished_at&.iso8601 if finished_at

        hash
      end
    end
  end
end
