# typed: true
# frozen_string_literal: true

class LoggingController < ApplicationController
  # Basic logging
  def test_basic
    # Test standard Rails logging - this is the primary usage pattern
    Rails.logger.info("Info level message")
    Rails.logger.warn("Warning level message")
    Rails.logger.debug("Debug level message with context")

    # For structured data, use LogStruct's Log::Plain
    plain_log = LogStruct::Log::Plain.new(
      message: "Structured log message",
      level: LogStruct::Level::Info,
      source: LogStruct::Source::App
    )
    Rails.logger.info(plain_log)

    # Test email scrubbing in plain string
    Rails.logger.info("User email is test@example.com and password is secret123")

    render json: {status: "ok", message: "Basic logging completed"}
  end

  # Error logging
  def test_error
    # Since the tests run in the test environment and Rails' test behavior may catch exceptions
    # differently, let's log the error but also raise it to ensure it's properly captured
    Rails.logger.info("About to raise test error")
    begin
      raise "Test error for integration testing"
    rescue => e
      # Log the error first
      error_log = LogStruct::Log::Error.new(
        source: LogStruct::Source::App,
        err_class: e.class,
        message: e.message
      )
      Rails.logger.error(error_log)

      # Then re-raise it for the test to catch
      raise
    end
  end

  # Custom log structures
  def test_custom
    # Create and log a custom log structure
    5.times do |i|
      custom_log = LogStruct::Log::Plain.new(
        message: "Custom log message #{i}",
        level: LogStruct::Level::Info,
        source: LogStruct::Source::App,
        data: {
          iteration: i,
          timestamp: Time.now.to_f,
          random: rand(100)
        }
      )
      Rails.logger.info(custom_log)
    end

    render json: {status: "ok", message: "Custom logging completed"}
  end

  # Request logging test - DO NOT MODIFY THIS METHOD
  # This method INTENTIONALLY reproduces the SystemStackError issue
  # which must be fixed in the LogStruct codebase itself.
  def test_request
    # This is exactly the code that was causing the infinite recursion issue
    # We need to fix the library - not modify this test!
    request_log = LogStruct::Log::Request.new(
      http_method: "GET",
      path: "/api/users",
      status: 200,
      duration: 15.5,
      source_ip: "127.0.0.1"
    )
    Rails.logger.info(request_log)

    render json: {status: "ok", message: "Request logging completed"}
  end

  # Model-related logging
  def test_model
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
  def test_job
    # Enqueue a job to test ActiveJob integration
    job = TestJob.perform_later("test_argument")
    Rails.logger.info("Job enqueued with ID: #{job.job_id}")

    # LogStruct will automatically enhance job enqueued/performed logs
    render json: {status: "ok", message: "Job enqueued for testing", job_id: job.job_id}
  end

  # Context and tagging
  def test_context
    # TODO: Fix types for the tagged method
    # Test Rails' built-in tagged logging
    T.unsafe(Rails.logger).tagged("REQUEST_ID_123", "USER_456") do
      Rails.logger.info("Message with tags")

      # Nested tags
      T.unsafe(Rails.logger).tagged("NESTED") do
        Rails.logger.warn("Message with nested tags")
      end
    end

    # Message without tags
    Rails.logger.info("Message without tags")

    render json: {status: "ok", message: "Context logging completed"}
  end

  def test_error_logging
    # Also test error handling in formatter by logging to trigger fallback handlers
    begin
      # Raise an error
      raise "Test error for recursion safety"
    rescue => e
      # Log the error, which would trigger the formatter code
      Rails.logger.error("Error occurred: #{e.message}")

      # Also try structured error logging
      error_log = LogStruct::Log::Error.new(
        source: LogStruct::Source::App,
        message: e.message,
        err_class: e.class
      )
      Rails.logger.error(error_log)
    end

    # If we got here without a SystemStackError, the infinite recursion was prevented
    render json: {status: "ok", message: "Stack-safe error handling test completed"}
  end
end
