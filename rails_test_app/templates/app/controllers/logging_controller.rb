# typed: true
# frozen_string_literal: true

class LoggingController < ApplicationController
  # Basic logging
  def basic
    # Test standard Rails logging - this is the primary usage pattern
    Rails.logger.info("Info level message")
    Rails.logger.warn("Warning level message")
    Rails.logger.debug("Debug level message with context")

    # For structured data, use LogStruct's Log::Plain
    plain_log = LogStruct::Log::Plain.new(
      message: "Structured log message",
      level: LogStruct::LogLevel::Info,
      source: LogStruct::Source::App
    )
    Rails.logger.info(plain_log)

    # Test email scrubbing in plain string
    Rails.logger.info("User email is test@example.com and password is secret123")

    render json: {status: "ok", message: "Basic logging completed"}
  end

  # Error logging
  def error
    # Test error logging with standard Rails approach
    begin
      # Deliberately raise an error
      raise StandardError, "Test error for logging"
    rescue => e
      # Standard Rails error logging
      Rails.logger.error("Error encountered: #{e.message}")

      # For more structured logging, use LogStruct::Log::Exception
      exception_log = LogStruct::Log::Exception.new(
        source: LogStruct::Source::App,
        err_class: e.class,
        message: e.message,
        data: {controller: "logging_controller", action: "error"}
      )
      Rails.logger.error(exception_log)
    end

    # Using the LogStruct.handle_exception helper (will trigger error reporting)
    custom_error = ArgumentError.new("Custom error for testing")
    LogStruct.handle_exception(custom_error, source: LogStruct::Source::App)

    render json: {status: "ok", message: "Error logging completed"}
  end

  # Model-related logging
  def model
    # Create a test user to trigger ActiveRecord logging
    user = User.create!(name: "Test User", email: "user@example.com")
    # Simple string logging
    Rails.logger.info("Created user #{user.id}")

    # Get the existing user
    found_user = User.find(user.id)
    Rails.logger.info("Found user: #{found_user.name}")

    render json: {status: "ok", message: "Model logging completed", user_id: user.id}
  end

  # Job-related logging
  def job
    # Enqueue a job to test ActiveJob integration
    job = TestJob.perform_later("test_argument")
    Rails.logger.info("Job enqueued with ID: #{job.job_id}")

    # LogStruct will automatically enhance job enqueued/performed logs
    render json: {status: "ok", message: "Job enqueued for testing", job_id: job.job_id}
  end

  # Structured logging
  def structured
    # Example of using built-in log structures for HTTP requests
    http_log = LogStruct::Log::Request.new(
      method: "GET",
      path: "/logging/structured",
      status: 200,
      duration_ms: 15.5,
      message: "HTTP Request details"
    )
    Rails.logger.info(http_log)

    # Example of using log structures for exceptions (without actually raising)
    exception_log = LogStruct::Log::Exception.new(
      exception: RuntimeError.new("Test exception"),
      err_class: "RuntimeError",
      message: "Structured exception log example",
      source: LogStruct::Source::App
    )
    Rails.logger.error(exception_log)

    render json: {status: "ok", message: "Structured logging completed"}
  end

  # Context and tagging
  def context
    # Test Rails' built-in tagged logging
    Rails.logger.tagged("REQUEST_ID_123", "USER_456") do
      Rails.logger.info("Message with tags")

      # Nested tags
      Rails.logger.tagged("NESTED") do
        Rails.logger.warn("Message with nested tags")
      end
    end

    # Message without tags
    Rails.logger.info("Message without tags")

    render json: {status: "ok", message: "Context logging completed"}
  end
end
