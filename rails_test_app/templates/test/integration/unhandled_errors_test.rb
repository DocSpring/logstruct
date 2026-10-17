# typed: true
# frozen_string_literal: true

require "test_helper"

# In production, ShowExceptions turns an error the app didn't handle into Rails' error page, and
# DebugExceptions logs it first
class UnhandledErrorsTest < ActionDispatch::IntegrationTest
  # Rails' settings these tests change
  SETTINGS = %w[action_dispatch.show_exceptions action_dispatch.show_detailed_exceptions action_dispatch.log_rescued_responses].freeze

  setup do
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
    @saved_env_config = Rails.application.env_config.slice(*SETTINGS)
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config.merge!(@saved_env_config)
  end

  test "an error the app didn't handle is one error line with the request and the status" do
    get "/logging/error"

    assert_response :internal_server_error
    rails_errors = lines.select { |line| line["src"] == "rails" && line["evt"] == "error" }

    assert_equal 1, rails_errors.size
    error = rails_errors.first

    assert_equal ["RuntimeError", "Test error for integration testing", 500, "/logging/error", "GET"],
      error.values_at("error_class", "msg", "status", "path", "method")
    assert_match %r{\Aapp/controllers/logging_controller\.rb:\d+}, error["backtrace"].first
    assert error["req_id"]
    # Rails' own text block isn't written
    assert_empty(lines.select { |line| line["msg"].to_s.include?("RuntimeError (Test error") })
  end

  test "a CSRF error has its security line, and no error line" do
    post "/security/submit", params: {name: "visible"}

    assert_response :unprocessable_entity
    assert_equal 1, lines.count { |line| line["evt"] == "csrf_violation" }
    assert_empty(lines.select { |line| line["src"] == "rails" && line["evt"] == "error" })
    assert_empty(lines.select { |line| line["msg"].to_s.include?("InvalidAuthenticityToken (") })
  end

  test "a routing error is an error line with its 404 status" do
    get "/no/such/route"

    assert_response :not_found
    error = lines.find { |line| line["evt"] == "error" }

    assert_equal ["rails", "ActionController::RoutingError", 404], error&.values_at("src", "error_class", "status")
  end

  test "config.action_dispatch.log_rescued_responses = false leaves out errors Rails rescues, like routing errors" do
    Rails.application.env_config["action_dispatch.log_rescued_responses"] = false

    get "/no/such/route"

    assert_response :not_found
    assert_empty(lines.select { |line| line["evt"] == "error" })
  end

  private

  def lines
    ::SemanticLogger.flush
    @log_output.string.lines.map { |line| JSON.parse(line) }
  end
end
