# typed: strict
# frozen_string_literal: true

require_relative "../../log_source"
require_relative "../../log_event"
require_relative "../../log/job"
require_relative "../../log/exception"

module LogStruct
  module Integrations
    module ActiveJob
      # Structured logging for ActiveJob
      class LogSubscriber < ::ActiveJob::LogSubscriber
        extend T::Sig
        
        sig { params(event: T.untyped).void }
        def enqueue(event)
          job = event.payload[:job]
          log_job_event(LogEvent::Enqueue, job, event)
        end

        sig { params(event: T.untyped).void }
        def enqueue_at(event)
          job = event.payload[:job]
          log_job_event(LogEvent::Schedule, job, event, scheduled_at: job.scheduled_at)
        end

        sig { params(event: T.untyped).void }
        def perform(event)
          job = event.payload[:job]
          exception = event.payload[:exception_object]

          if exception
            # Log the exception with the job context
            log_exception(exception, job, event)
          else
            log_job_event(LogEvent::Finish, job, event, duration: event.duration.round(2))
          end
        end

        sig { params(event: T.untyped).void }
        def perform_start(event)
          job = event.payload[:job]
          log_job_event(LogEvent::Start, job, event)
        end

        private

        sig { params(event_type: T.any(LogEvent::Enqueue, LogEvent::Schedule, LogEvent::Start, LogEvent::Finish), job: T.untyped, _event: T.untyped, additional_data: T::Hash[Symbol, T.untyped]).void }
        def log_job_event(event_type, job, _event, additional_data = {})
          # Create structured log data
          log_data = Log::Job.new(
            event: event_type,
            job_id: job.job_id,
            job_class: job.class.to_s,
            queue_name: job.queue_name,
            duration: additional_data[:duration],
            # Add arguments if the job class allows it
            arguments: job.class.log_arguments? ? job.arguments : nil,
            # Store additional data in the data hash
            data: {
              executions: job.executions,
              scheduled_at: additional_data[:scheduled_at],
              provider_job_id: job.provider_job_id
            }.compact
          )

          # Use Rails logger with our structured formatter
          logger.info(log_data)
        end

        sig { params(exception: StandardError, job: T.untyped, _event: T.untyped).void }
        def log_exception(exception, job, _event)
          # Create job context data for the exception
          job_context = {
            job_id: job.job_id,
            job_class: job.class.to_s,
            queue_name: job.queue_name,
            executions: job.executions,
            provider_job_id: job.provider_job_id
          }

          # Add arguments if the job class allows it
          job_context[:arguments] = job.arguments if job.class.log_arguments?

          # Create exception log with job source and context
          log_data = Log::Exception.from_exception(
            Source::Job,
            exception,
            job_context
          )

          # Use Rails logger with our structured formatter
          logger.error(log_data)
        end

        sig { returns(::ActiveSupport::Logger) }
        def logger
          ::ActiveJob::Base.logger
        end
      end
    end
  end
end
