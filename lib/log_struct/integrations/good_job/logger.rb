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
      # ## Benefits:
      # - High-performance logging with SemanticLogger backend
      # - Structured GoodJob-specific log entries
      # - Automatic job context capture
      # - Thread and process information
      # - Performance metrics and timing data
      #
      # ## Usage:
      # This logger is automatically configured when the GoodJob integration
      # is enabled. It replaces GoodJob.logger to provide structured logging
      # for all GoodJob operations.
      class Logger < LogStruct::SemanticLogger::Logger
        extend T::Sig

        # Override log methods to create GoodJob-specific log structs
        %i[debug info warn error fatal].each do |level|
          define_method(level) do |message = nil, payload = nil, &block|
            # Extract basic job context from thread-local variables
            job_context = {}

            if Thread.current[:good_job_execution]
              execution = Thread.current[:good_job_execution]
              if execution.respond_to?(:job_id)
                job_context[:job_id] = execution.job_id
                job_context[:job_class] = execution.job_class if execution.respond_to?(:job_class)
                job_context[:queue_name] = execution.queue_name if execution.respond_to?(:queue_name)
                job_context[:executions] = execution.executions if execution.respond_to?(:executions)
                job_context[:scheduled_at] = execution.scheduled_at if execution.respond_to?(:scheduled_at)
                job_context[:priority] = execution.priority if execution.respond_to?(:priority)
              end
            end

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
      end
    end
  end
end
