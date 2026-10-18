# typed: strict
# frozen_string_literal: true

require_relative "../../semantic_logger/logger"
require_relative "../../log/good_job"
require_relative "../../enums/source"

module LogStruct
  module Integrations
    module GoodJob
      # Custom Logger for GoodJob that creates LogStruct::Log::GoodJob entries
      #
      # This logger extends LogStruct's SemanticLogger to provide optimal logging
      # performance while creating structured log entries specifically for GoodJob
      # operations and events.
      #
      # GoodJob's own messages are logged as Log::GoodJob::Log lines with the process and thread,
      # and, during a job, the job's ID, class, queue, execution count, scheduled time and priority.
      #
      # ## Usage:
      # This logger is automatically configured when the GoodJob integration
      # is enabled. It replaces GoodJob.logger to provide structured logging
      # for all GoodJob operations.
      class Logger < LogStruct::SemanticLogger::Logger
        extend T::Sig

        # Override log methods to create GoodJob-specific log structs
        %i[debug info warn error fatal].each do |level|
          define_method(level) do |message = nil, payload = nil, exception = nil, &block|
            # LogStruct log entries and Hashes (like the thread error handler's) are logged as they are, and a
            # message with an exception is an error line with both
            if !(message.nil? || message.is_a?(String)) || exception || payload.is_a?(Exception)
              next super(message, payload, exception, &block)
            end

            job_context = Logger.current_job_context

            log_struct = Log::GoodJob::Log.new(
              message: message || (block ? block.call : ""),
              process_id: ::Process.pid,
              thread_id: Thread.current.object_id.to_s(36),
              job_id: job_context[:job_id],
              job_class: job_context[:job_class],
              queue_name: job_context[:queue_name],
              executions: job_context[:executions],
              scheduled_at: job_context[:scheduled_at],
              priority: job_context[:priority]
            )

            super(log_struct, payload, &nil)
          end
        end

        # The job GoodJob is running on this thread: CurrentThread.job (a GoodJob::Job) in GoodJob 4,
        # CurrentThread.execution in GoodJob 3
        sig { returns(T::Hash[Symbol, T.untyped]) }
        def self.current_job_context
          return {} unless defined?(::GoodJob::CurrentThread)

          current = ::GoodJob::CurrentThread
          job = (current.job if current.respond_to?(:job)) || (current.execution if current.respond_to?(:execution))
          return {} unless job

          job_class = job.try(:job_class) || job.try(:serialized_params)&.dig("job_class")
          {
            job_id: job.try(:active_job_id)&.to_s,
            job_class: job_class&.to_s,
            queue_name: job.try(:queue_name)&.to_sym,
            executions: job.try(:executions_count) || job.try(:executions),
            scheduled_at: job.try(:scheduled_at),
            priority: job.try(:priority)
          }
        end
      end
    end
  end
end
