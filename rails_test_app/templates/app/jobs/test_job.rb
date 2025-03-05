# typed: true
# frozen_string_literal: true

class TestJob < ApplicationJob
  queue_as :default

  def perform(arg)
    # Log job processing - standard Rails approach
    logger.info("Processing job #{job_id} with argument: #{arg}")

    # Simulate some work
    sleep 0.1

    # Test error handling in a job
    begin
      raise StandardError, "Test job error"
    rescue => e
      # Standard Rails logging
      logger.error("Job error: #{e.message}")

      # Example of enhanced structured logging
      exception_log = LogStruct::Log::Exception.new(
        source: LogStruct::Source::Job,
        err_class: e.class,
        message: e.message,
        data: {job_class: self.class.name, job_id: job_id}
      )
      logger.error(exception_log)
    end

    # Log job completion
    logger.info("Job #{job_id} completed successfully")
  end
end
