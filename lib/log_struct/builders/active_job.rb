# typed: strict
# frozen_string_literal: true

require_relative "../log/active_job/enqueue"
require_relative "../log/active_job/schedule"
require_relative "../log/active_job/start"
require_relative "../log/active_job/finish"

module LogStruct
  module Builders
    module ActiveJob
      extend T::Sig

      sig { params(job: T.untyped).returns(T.nilable(String)) }
      def self.safe_provider_job_id(job)
        job.respond_to?(:provider_job_id) ? job.provider_job_id : nil
      end

      sig { params(job: T.untyped).returns(T.nilable(Integer)) }
      def self.safe_executions(job)
        job.respond_to?(:executions) ? job.executions : nil
      end

      # Respect log_arguments? setting on job classes.
      # Arguments are logged by default but can be opted-out per job class.
      # When logged, sensitive keys are filtered by Formatter.process_values.
      sig { params(job: T.untyped).returns(T.nilable(T::Array[T.untyped])) }
      def self.safe_arguments(job)
        return job.arguments unless job.class.respond_to?(:log_arguments?)
        job.class.log_arguments? ? job.arguments : nil
      end

      sig { params(job: T.untyped).returns(Log::ActiveJob::Enqueue) }
      def self.enqueue(job)
        Log::ActiveJob::Enqueue.new(
          job_id: job.job_id,
          job_class: job.class.to_s,
          queue_name: job.queue_name,
          arguments: safe_arguments(job),
          executions: safe_executions(job),
          provider_job_id: safe_provider_job_id(job)
        )
      end

      sig { params(job: T.untyped, scheduled_at: Time).returns(Log::ActiveJob::Schedule) }
      def self.schedule(job, scheduled_at:)
        Log::ActiveJob::Schedule.new(
          job_id: job.job_id,
          job_class: job.class.to_s,
          queue_name: job.queue_name,
          arguments: safe_arguments(job),
          executions: safe_executions(job),
          provider_job_id: safe_provider_job_id(job),
          scheduled_at: scheduled_at
        )
      end

      sig { params(job: T.untyped, started_at: Time, attempt: T.nilable(Integer)).returns(Log::ActiveJob::Start) }
      def self.start(job, started_at:, attempt:)
        Log::ActiveJob::Start.new(
          job_id: job.job_id,
          job_class: job.class.to_s,
          queue_name: job.queue_name,
          arguments: safe_arguments(job),
          executions: safe_executions(job),
          provider_job_id: safe_provider_job_id(job),
          started_at: started_at,
          attempt: attempt
        )
      end

      sig { params(job: T.untyped, duration_ms: Float, finished_at: Time).returns(Log::ActiveJob::Finish) }
      def self.finish(job, duration_ms:, finished_at:)
        Log::ActiveJob::Finish.new(
          job_id: job.job_id,
          job_class: job.class.to_s,
          queue_name: job.queue_name,
          arguments: safe_arguments(job),
          executions: safe_executions(job),
          provider_job_id: safe_provider_job_id(job),
          duration_ms: duration_ms,
          finished_at: finished_at
        )
      end
    end
  end
end
