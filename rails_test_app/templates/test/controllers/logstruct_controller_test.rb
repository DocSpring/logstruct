# typed: true
# frozen_string_literal: true

require "test_helper"

class LogstructTest < ActionDispatch::IntegrationTest
  # Basic test to ensure the Rails app is working
  def test_healthcheck_works
    get "/health"

    assert_response :success
    assert_equal "OK", response.body
  end

  # More detailed test to verify basic logging
  def test_basic_logging_endpoint_works
    get "/logging/basic"

    assert_response :success

    response_json = JSON.parse(response.body)

    assert_equal "ok", response_json["status"]
    assert_equal "Basic logging completed", response_json["message"]
  end

  # Test error logging
  def test_error_logging_endpoint_works
    # The error will be raised and we should see it
    error_raised = false

    begin
      get "/logging/error"
    rescue RuntimeError => e
      error_raised = true

      assert_equal "Test error for integration testing", e.message
    end

    assert error_raised, "Expected an error to be raised"
  end

  # Test custom log structures
  def test_custom_log_classs_work
    get "/logging/custom"

    assert_response :success

    response_json = JSON.parse(response.body)

    assert_equal "ok", response_json["status"]
    assert_equal "Custom logging completed", response_json["message"]
  end

  # Test request logging
  def test_request_logging_works
    get "/logging/request"

    assert_response :success

    response_json = JSON.parse(response.body)

    assert_equal "ok", response_json["status"]
    assert_equal "Request logging completed", response_json["message"]
  end

  # Test that error handling is stack-safe
  def test_error_logging
    # This test intentionally creates a situation that would cause
    # an infinite loop if error handling is not implemented correctly
    get "/logging/error_logging"

    assert_response :success

    response_json = JSON.parse(response.body)

    assert_equal "ok", response_json["status"]
    assert_equal "Stack-safe error handling test completed", response_json["message"]
  end
end
