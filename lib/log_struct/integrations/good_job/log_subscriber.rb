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
        sig { params(event: T.untyped).void }
        def enqueue(event)
          job_data = extract_job_data(event)
          
          log_entry = LogStruct::Log::GoodJob.new(
            event: Event::Enqueue,
            level: Level::Info,
            job_id: job_data[:job_id],
            job_class: job_data[:job_class],
            queue_name: job_data[:queue_name],
            arguments: job_data[:arguments],
            scheduled_at: job_data[:scheduled_at],
            priority: job_data[:priority],
            execution_time: event.duration,
            additional_data: {
              enqueue_caller: job_data[:caller_location]
            }
          )

          logger.info(log_entry)
        end

        # Job execution started event
        sig { params(event: T.untyped).void }
        def start(event)
          job_data = extract_job_data(event)
          
          log_entry = LogStruct::Log::GoodJob.new(
            event: Event::Start,
            level: Level::Info,
            job_id: job_data[:job_id],
            job_class: job_data[:job_class],
            queue_name: job_data[:queue_name],
            arguments: job_data[:arguments],
            executions: job_data[:executions],
            wait_time: job_data[:wait_time],
            scheduled_at: job_data[:scheduled_at],
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36)
          )

          logger.info(log_entry)
        end

        # Job completed successfully event  
        sig { params(event: T.untyped).void }
        def finish(event)
          job_data = extract_job_data(event)
          
          log_entry = LogStruct::Log::GoodJob.new(
            event: Event::Finish,
            level: Level::Info,
            job_id: job_data[:job_id],
            job_class: job_data[:job_class],
            queue_name: job_data[:queue_name],
            executions: job_data[:executions],
            run_time: event.duration,
            finished_at: Time.now,
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36),
            additional_data: {
              result: job_data[:result]
            }
          )

          logger.info(log_entry)
        end

        # Job failed with error event
        sig { params(event: T.untyped).void }
        def error(event)
          job_data = extract_job_data(event)
          
          log_entry = LogStruct::Log::GoodJob.new(
            event: Event::Error,
            level: Level::Error,
            job_id: job_data[:job_id],
            job_class: job_data[:job_class],
            queue_name: job_data[:queue_name],
            executions: job_data[:executions],
            exception_executions: job_data[:exception_executions],
            error_class: job_data[:error_class],
            error_message: job_data[:error_message],
            error_backtrace: job_data[:error_backtrace],
            run_time: event.duration,
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36)
          )

          logger.error(log_entry)
        end

        # Job scheduled for future execution event
        sig { params(event: T.untyped).void }
        def schedule(event)
          job_data = extract_job_data(event)
          
          log_entry = LogStruct::Log::GoodJob.new(
            event: Event::Schedule,
            level: Level::Info,
            job_id: job_data[:job_id],
            job_class: job_data[:job_class],
            queue_name: job_data[:queue_name],
            arguments: job_data[:arguments],
            scheduled_at: job_data[:scheduled_at],
            priority: job_data[:priority],
            cron_key: job_data[:cron_key],
            execution_time: event.duration
          )

          logger.info(log_entry)
        end

        private

        # Extract job data from ActiveSupport event payload
        sig { params(event: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
        def extract_job_data(event)
          payload = event.payload || {}
          job = payload[:job]
          execution = payload[:execution] || payload[:good_job_execution]
          exception = payload[:exception] || payload[:error]

          data = {}

          # Basic job information
          if job
            data[:job_id] = job.job_id if job.respond_to?(:job_id)
            data[:job_class] = job.job_class if job.respond_to?(:job_class)  
            data[:queue_name] = job.queue_name if job.respond_to?(:queue_name)
            data[:arguments] = job.arguments if job.respond_to?(:arguments)
            data[:priority] = job.priority if job.respond_to?(:priority)
            data[:scheduled_at] = job.scheduled_at if job.respond_to?(:scheduled_at)
            data[:cron_key] = job.cron_key if job.respond_to?(:cron_key)
            data[:caller_location] = job.enqueue_caller_location if job.respond_to?(:enqueue_caller_location)
          end

          # Execution-specific information
          if execution
            data[:executions] = execution.executions if execution.respond_to?(:executions)
            data[:exception_executions] = execution.exception_executions if execution.respond_to?(:exception_executions)
            # Use existing wait_time if available, otherwise calculate it
            if execution.respond_to?(:wait_time) && execution.wait_time
              data[:wait_time] = execution.wait_time
            elsif execution.respond_to?(:created_at)
              data[:wait_time] = calculate_wait_time(execution)
            end
            data[:batch_id] = execution.batch_id if execution.respond_to?(:batch_id)
            data[:cron_key] ||= execution.cron_key if execution.respond_to?(:cron_key)
          end

          # Error information
          if exception
            data[:error_class] = exception.class.name
            data[:error_message] = exception.message
            data[:error_backtrace] = exception.backtrace&.first(20) # Limit backtrace size
          end

          # Result information
          data[:result] = payload[:result] if payload.key?(:result)

          data
        end

        # Calculate wait time from job creation to execution start
        sig { params(execution: T.untyped).returns(T.nilable(Float)) }
        def calculate_wait_time(execution)
          return nil unless execution.respond_to?(:created_at)
          return nil unless execution.respond_to?(:performed_at)
          return nil unless execution.created_at && execution.performed_at

          (execution.performed_at - execution.created_at).to_f
        rescue => e
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