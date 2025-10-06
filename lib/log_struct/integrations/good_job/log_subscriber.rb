# typed: strict
# frozen_string_literal: true

begin
  require "active_support/log_subscriber"
rescue LoadError
  # ActiveSupport is not available, log subscriber will be skipped
end

require_relative "../../log/good_job"
require_relative "../../enums/event"
require_relative "../../enums/level"

module LogStruct
  module Integrations
    module GoodJob
      # LogSubscriber for GoodJob ActiveSupport notifications
      #
      # This subscriber captures GoodJob's ActiveSupport notifications and converts
      # them into structured LogStruct::Log::GoodJob entries. It provides detailed
      # logging for job lifecycle events, performance metrics, and error tracking.
      #
      # ## Supported Events:
      # - job.enqueue - Job queued for execution
      # - job.start - Job execution started
      # - job.finish - Job completed successfully
      # - job.error - Job failed with error
      # - job.retry - Job retry initiated
      # - job.schedule - Job scheduled for future execution
      #
      # ## Event Data Captured:
      # - Job identification (ID, class, queue)
      # - Execution context (arguments, priority, scheduled time)
      # - Performance metrics (execution time, wait time)
      # - Error information (class, message, backtrace)
      # - Process and thread information
      class LogSubscriber < ::ActiveSupport::LogSubscriber
        extend T::Sig

        # Job enqueued event
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue(event)
          payload = T.let(event.payload, T::Hash[Symbol, T.untyped])
          job = payload[:job]
          base_fields = build_base_fields(job, payload)
          ts = event.time ? Time.at(event.time) : Time.now

          logger.info(Log::GoodJob::Enqueue.new(
            **base_fields.to_kwargs,
            scheduled_at: (job&.scheduled_at ? Time.at(job.scheduled_at.to_i) : nil),
            duration_ms: event.duration.to_f,
            enqueue_caller: job&.enqueue_caller_location,
            timestamp: ts
          ))
        end

        # Job execution started event
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def start(event)
          payload = T.let(event.payload, T::Hash[Symbol, T.untyped])
          job = payload[:job]
          execution = payload[:execution] || payload[:good_job_execution]
          base_fields = build_base_fields(job, payload)
          ts = event.time ? Time.at(event.time) : Time.now

          logger.info(Log::GoodJob::Start.new(
            **base_fields.to_kwargs,
            wait_ms: begin
              wt = execution&.wait_time || calculate_wait_time(execution)
              wt ? (wt.to_f * 1000.0) : nil
            end,
            scheduled_at: (job&.scheduled_at ? Time.at(job.scheduled_at.to_i) : nil),
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36),
            timestamp: ts
          ))
        end

        # Job completed successfully event
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def finish(event)
          payload = T.let(event.payload, T::Hash[Symbol, T.untyped])
          job = payload[:job]
          base_fields = build_base_fields(job, payload)
          start_ts = event.time ? Time.at(event.time) : Time.now
          end_ts = event.end ? Time.at(event.end) : Time.now

          logger.info(Log::GoodJob::Finish.new(
            **base_fields.to_kwargs,
            duration_ms: event.duration.to_f,
            finished_at: end_ts,
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36),
            result: payload[:result]&.to_s,
            timestamp: start_ts
          ))
        end

        # Job failed with error event
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def error(event)
          payload = T.let(event.payload, T::Hash[Symbol, T.untyped])
          job = payload[:job]
          execution = payload[:execution] || payload[:good_job_execution]
          exception = payload[:exception] || payload[:error]
          ts = event.time ? Time.at(event.time) : Time.now
          base_fields = build_base_fields(job, payload)

          logger.error(Log::GoodJob::Error.new(
            **base_fields.to_kwargs,
            exception_executions: execution&.exception_executions,
            error_class: exception&.class&.name,
            error_message: exception&.message,
            backtrace: exception&.backtrace,
            duration_ms: event.duration.to_f,
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36),
            timestamp: ts
          ))
        end

        # Job scheduled for future execution event
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def schedule(event)
          payload = T.let(event.payload, T::Hash[Symbol, T.untyped])
          job = payload[:job]
          base_fields = build_base_fields(job, payload)
          ts = event.time ? Time.at(event.time) : Time.now

          logger.info(Log::GoodJob::Schedule.new(
            **base_fields.to_kwargs,
            scheduled_at: (job&.scheduled_at ? Time.at(job.scheduled_at.to_i) : nil),
            priority: job&.priority,
            cron_key: job&.cron_key,
            duration_ms: event.duration.to_f,
            timestamp: ts
          ))
        end

        private

        # Build BaseFields from job + payload (execution)
        sig { params(job: T.untyped, payload: T::Hash[Symbol, T.untyped]).returns(Log::GoodJob::BaseFields) }
        def build_base_fields(job, payload)
          execution = payload[:execution] || payload[:good_job_execution]
          Log::GoodJob::BaseFields.new(
            job_id: job&.job_id,
            job_class: job&.job_class,
            queue_name: job&.queue_name&.to_sym,
            arguments: job&.arguments,
            executions: execution&.executions
          )
        end

        # Calculate wait time from job creation to execution start
        sig { params(execution: T.untyped).returns(T.nilable(Float)) }
        def calculate_wait_time(execution)
          return nil unless execution.respond_to?(:created_at)
          return nil unless execution.respond_to?(:performed_at)
          return nil unless execution.created_at && execution.performed_at

          (execution.performed_at - execution.created_at).to_f
        rescue
          # Return nil if calculation fails
          nil
        end

        # Get the appropriate logger for GoodJob events
        sig { returns(T.untyped) }
        def logger
          # Always use Rails.logger - in production it will be configured by the integration setup,
          # in tests it will be set up by the test harness
          Rails.logger
        end
      end
    end
  end
end
