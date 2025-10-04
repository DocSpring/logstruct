# typed: strict
# frozen_string_literal: true

require_relative "../../enums/source"
require_relative "../../enums/event"
require_relative "../../log/active_job"
require_relative "../../log/error"

module LogStruct
  module Integrations
    module ActiveJob
      # Structured logging for ActiveJob
      class LogSubscriber < ::ActiveJob::LogSubscriber
        extend T::Sig

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          ts = event.time ? Time.at(event.time) : Time.now
          base_fields = build_base_fields(job)
          logger.info(Log::ActiveJob::Enqueue.new(
            **base_fields.to_kwargs,
            timestamp: ts
          ))
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue_at(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          ts = event.time ? Time.at(event.time) : Time.now
          base_fields = build_base_fields(job)
          logger.info(Log::ActiveJob::Schedule.new(
            **base_fields.to_kwargs,
            scheduled_at: job.scheduled_at,
            timestamp: ts
          ))
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def perform(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          exception = event.payload[:exception_object]

          if exception
            # Log the exception with the job context
            log_exception(exception, job, event)
          else
            start_float = event.time
            end_float = event.end
            ts = start_float ? Time.at(start_float) : Time.now
            finished_at = end_float ? Time.at(end_float) : Time.now
            base_fields = build_base_fields(job)
            logger.info(Log::ActiveJob::Finish.new(
              **base_fields.to_kwargs,
              duration_ms: event.duration.to_f,
              finished_at: finished_at,
              timestamp: ts
            ))
          end
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def perform_start(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          ts = event.time ? Time.at(event.time) : Time.now
          started_at = ts
          attempt = job.executions
          base_fields = build_base_fields(job)
          logger.info(Log::ActiveJob::Start.new(
            **base_fields.to_kwargs,
            started_at: started_at,
            attempt: attempt,
            timestamp: ts
          ))
        end

        private

        sig { params(job: ::ActiveJob::Base).returns(Log::ActiveJob::BaseFields) }
        def build_base_fields(job)
          Log::ActiveJob::BaseFields.new(
            job_id: job.job_id,
            job_class: job.class.to_s,
            queue_name: job.queue_name&.to_sym,
            executions: job.executions,
            provider_job_id: job.provider_job_id,
            arguments: ((job.class.respond_to?(:log_arguments?) && job.class.log_arguments?) ? job.arguments : nil)
          )
        end

        sig { params(exception: StandardError, job: ::ActiveJob::Base, _event: ::ActiveSupport::Notifications::Event).void }
        def log_exception(exception, job, _event)
          base_fields = build_base_fields(job)
          job_context = base_fields.to_kwargs

          log_data = Log.from_exception(Source::Job, exception, job_context)

          logger.error(log_data)
        end

        sig { returns(T.untyped) }
        def logger
          ::ActiveJob::Base.logger
        end
      end
    end
  end
end
