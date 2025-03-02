# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActiveJob
      # Structured logging for ActiveJob
      class LogSubscriber < ::ActiveJob::LogSubscriber
        def enqueue(event)
          job = event.payload[:job]
          log_job_event("active_job_enqueued", job, event)
        end

        def enqueue_at(event)
          job = event.payload[:job]
          log_job_event("active_job_enqueued_at", job, event)
        end

        def perform(event)
          job = event.payload[:job]
          exception = event.payload[:exception_object]

          if exception
            log_job_event("active_job_failed", job, event, exception: exception)
          else
            log_job_event("active_job_performed", job, event, duration: event.duration.round(2))
          end
        end

        def perform_start(event)
          job = event.payload[:job]
          log_job_event("active_job_performing", job, event)
        end

        private

        def log_job_event(event_name, job, _event, additional_data = {})
          log_data = {
            src: "active_job",
            evt: event_name,
            ts: Time.now.iso8601(3),
            pid: Process.pid,
            job_id: job.job_id,
            job_class: job.class.to_s,
            queue_name: job.queue_name,
            executions: job.executions
          }

          # Format arguments if the job class allows it
          log_data[:arguments] = job.arguments.map { |arg| format(arg) } if job.class.log_arguments? && job.arguments.any?

          # Add scheduled_at if present
          log_data[:scheduled_at] = job.scheduled_at.iso8601(3) if job.scheduled_at

          # Add provider_job_id if present
          log_data[:provider_job_id] = job.provider_job_id if job.provider_job_id

          # Add exception details if present
          if additional_data[:exception]
            exception = additional_data[:exception]
            log_data[:error_class] = exception.class.to_s
            log_data[:error_message] = exception.message
            log_data[:backtrace] = exception.backtrace&.first(5)
          end

          # Add duration if present
          log_data[:duration_ms] = additional_data[:duration] if additional_data[:duration]

          # Use Rails logger with our structured formatter
          logger.info(log_data)
        end

        def logger
          ::ActiveJob::Base.logger
        end
      end
    end
  end
end
