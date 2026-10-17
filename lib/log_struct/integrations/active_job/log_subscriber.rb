# typed: strict
# frozen_string_literal: true

require "active_support/log_subscriber"
require_relative "../../enums/source"
require_relative "../../enums/event"
require_relative "../../log/active_job"
require_relative "../../log/error"
require_relative "../event_time"

module LogStruct
  module Integrations
    module ActiveJob
      # Structured logging for ActiveJob
      class LogSubscriber < ::ActiveSupport::LogSubscriber
        extend T::Sig

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue(event)
          log_enqueue(event)
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue_at(event)
          log_enqueue(event)
        end

        # perform_all_later: a line for each job, as perform_later writes
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue_all(event)
          ts = EventTime.coerce_event_time(event.time)
          jobs = Array(event.payload[:jobs]).grep(::ActiveJob::Base)
          error = event.payload[:exception_object]
          if error
            log_enqueue_all_error(error, jobs, ts)
            return
          end

          # Adapters with their own enqueue_all (Sidekiq's) say only how many jobs they enqueued
          if jobs.none? { |job| job.successfully_enqueued? || job.enqueue_error }
            log_enqueued_count(jobs, event.payload[:enqueued_count], ts)
            return
          end

          jobs.each do |job|
            if job.successfully_enqueued?
              log_enqueued(job, ts)
            elsif job.enqueue_error
              log_exception(job.enqueue_error, job)
            end
          end
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def perform(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          exception = event.payload[:exception_object]

          if exception
            # Log the exception with the job context
            log_exception(exception, job)
          # An aborted job didn't run: a before_perform callback stopped it
          elsif !event.payload[:aborted]
            finished_at = EventTime.coerce_event_time(event.end)
            base_fields = build_base_fields(job)
            logger.info(Log::ActiveJob::Finish.new(
              **base_fields.to_kwargs,
              duration_ms: event.duration.to_f,
              finished_at: finished_at,
              timestamp: finished_at
            ))
          end
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def perform_start(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          ts = EventTime.coerce_event_time(event.time)
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

        # retry_on caught the exception and enqueued the job again
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def enqueue_retry(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          # retry_job can be called without an exception or a wait
          error = event.payload[:error]
          wait = event.payload[:wait]
          logger.info(Log::ActiveJob::Retry.new(
            **build_base_fields(job).to_kwargs,
            error_class: error&.class,
            message: error&.message,
            wait_ms: wait.nil? ? nil : wait.to_f * 1000,
            timestamp: EventTime.coerce_event_time(event.time)
          ))
        end

        # retry_on ran out of attempts. The job then raises the exception (an error line), unless
        # retry_on was given a block.
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def retry_stopped(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          error = T.cast(event.payload[:error], Exception)
          logger.error(Log::ActiveJob::RetryStopped.new(
            **build_base_fields(job).to_kwargs,
            error_class: error.class,
            message: error.message,
            timestamp: EventTime.coerce_event_time(event.time)
          ))
        end

        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def discard(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          error = T.cast(event.payload[:error], Exception)
          logger.error(Log::ActiveJob::Discard.new(
            **build_base_fields(job).to_kwargs,
            error_class: error.class,
            message: error.message,
            timestamp: EventTime.coerce_event_time(event.time)
          ))
        end

        private

        # Like Rails' own enqueue lines: a job the queue didn't take writes an error line, and one a
        # before_enqueue callback stopped writes none
        sig { params(event: ::ActiveSupport::Notifications::Event).void }
        def log_enqueue(event)
          job = T.cast(event.payload[:job], ::ActiveJob::Base)
          # perform_later rescues ActiveJob::EnqueueError and keeps it on the job
          error = event.payload[:exception_object] || job.enqueue_error
          if error
            # With the inline adapter, a job that fails raises out of perform_later, and its perform line has
            # already logged the error
            log_exception(error, job) unless LogStruct::LoggedErrors.logged?(error)
          elsif !event.payload[:aborted]
            log_enqueued(job, EventTime.coerce_event_time(event.time))
          end
        end

        sig { params(job: ::ActiveJob::Base, ts: Time).void }
        def log_enqueued(job, ts)
          base_fields = build_base_fields(job)
          scheduled_at = job.scheduled_at
          if scheduled_at
            logger.info(Log::ActiveJob::Schedule.new(**base_fields.to_kwargs, scheduled_at: scheduled_at, timestamp: ts))
          else
            logger.info(Log::ActiveJob::Enqueue.new(**base_fields.to_kwargs, timestamp: ts))
          end
        end

        # perform_all_later raised: the adapter did (Redis down, say), or with the inline adapter a job did
        sig { params(error: Exception, jobs: T::Array[::ActiveJob::Base], ts: Time).void }
        def log_enqueue_all_error(error, jobs, ts)
          # Rails' own enqueue loop (for adapters without enqueue_all) marks each job it tried
          tried = jobs.reject { |job| job.successfully_enqueued?.nil? }
          unless tried.empty?
            tried.each { |job| log_enqueued(job, ts) if job.successfully_enqueued? }
            failed = tried.find { |job| !job.successfully_enqueued? }
            # With the inline adapter, the error is a job's own, which its perform line has logged
            log_exception(error, failed) if failed && !LogStruct::LoggedErrors.logged?(error)
            return
          end
          return if LogStruct::LoggedErrors.logged?(error)

          # An adapter's own enqueue_all (Sidekiq's) doesn't say which jobs it enqueued before it raised
          classes = jobs.map { |job| job.class.to_s }.uniq.join(", ")
          logger.error(Log::Error.new(
            source: Source::Job,
            error_class: error.class,
            message: "perform_all_later of #{jobs.size} jobs (#{classes}) failed; the queue adapter doesn't say which it enqueued",
            error_message: error.message,
            backtrace: error.backtrace,
            level: Level::Error,
            timestamp: ts
          ))
          LogStruct::LoggedErrors.mark(error)
        end

        # Every job's line when the adapter enqueued them all; when it didn't, it doesn't say which it enqueued
        sig { params(jobs: T::Array[::ActiveJob::Base], enqueued_count: T.untyped, ts: Time).void }
        def log_enqueued_count(jobs, enqueued_count, ts)
          return if jobs.empty?

          if enqueued_count == jobs.size
            jobs.each { |job| log_enqueued(job, ts) }
          else
            classes = jobs.map { |job| job.class.to_s }.uniq.join(", ")
            logger.warn("perform_all_later enqueued #{enqueued_count.to_i} of #{jobs.size} jobs (#{classes}); the queue adapter doesn't say which")
          end
        end

        sig { params(job: ::ActiveJob::Base).returns(Log::ActiveJob::BaseFields) }
        def build_base_fields(job)
          Log::ActiveJob::BaseFields.new(
            job_id: job.job_id,
            job_class: job.class.to_s,
            queue_name: job.queue_name&.to_sym,
            executions: job.executions,
            # Backends use Strings or Integers (SolidQueue uses its job row ID)
            provider_job_id: job.provider_job_id&.to_s,
            arguments: logged_arguments(job)
          )
        end

        # ActionMailer's delivery job carries the mail's own arguments, which can be secrets: Devise passes its
        # confirmation, password reset and invitation tokens as plain strings, which no key-based filter can find.
        # For a mail, log the mailer, the mail and the delivery method only.
        sig { params(job: ::ActiveJob::Base).returns(T.nilable(T::Array[T.untyped])) }
        def logged_arguments(job)
          return nil unless job.class.respond_to?(:log_arguments?) && job.class.log_arguments?
          return job.arguments.first(3) if defined?(::ActionMailer::MailDeliveryJob) && job.is_a?(::ActionMailer::MailDeliveryJob)

          job.arguments
        end

        # perform_now lets any Exception through, not only StandardErrors
        sig { params(exception: Exception, job: ::ActiveJob::Base).void }
        def log_exception(exception, job)
          log_data = Log::ActiveJob::Error.new(
            **build_base_fields(job).to_kwargs,
            error_class: exception.class,
            message: exception.message,
            backtrace: exception.backtrace
          )

          logger.error(log_data)
          # So a backend that reports the same exception (GoodJob's on_thread_error) doesn't log it again
          LogStruct::LoggedErrors.mark(exception)
        end

        sig { returns(T.untyped) }
        def logger
          ::ActiveJob::Base.logger
        end
      end
    end
  end
end
