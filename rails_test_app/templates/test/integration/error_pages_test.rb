# typed: true
# frozen_string_literal: true

require "test_helper"

# With config.exceptions_app = routes, Rails renders the error page by sending the request through the routes again
# as GET /<status>, so the error page's controller logs a request line of its own
class ErrorPagesTest < ActionDispatch::IntegrationTest
  # Rails' settings these tests change
  SETTINGS = %w[action_dispatch.show_exceptions action_dispatch.show_detailed_exceptions].freeze

  setup do
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
    @saved_env_config = Rails.application.env_config.slice(*SETTINGS)
    Rails.application.env_config["action_dispatch.show_exceptions"] = :all
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    Rails.application.config.x.error_pages_from_routes = true
  end

  teardown do
    Rails.application.env_config.merge!(@saved_env_config)
    Rails.application.config.x.error_pages_from_routes = false
  end

  test "an action that raises logs one request line, its own" do
    get "/logging/error"

    assert_response :internal_server_error
    assert_equal({"status" => 500}, response.parsed_body)
    assert_equal [["GET", "/logging/error", "LoggingController", "test_error", 500]], request_lines
  end

  test "a POST whose action raises logs its own method and path" do
    post "/security/submit"

    assert_response :unprocessable_entity
    assert_equal [["POST", "/security/submit", "SecurityController", "submit", 422]], request_lines
  end

  test "an error raised before any action logs the error page's line with the request's method and path" do
    post "/no/such/route?page=2"

    assert_response :not_found
    assert_equal [["POST", "/no/such/route", "ErrorsController", "show", 404]], request_lines
  end

  private

  def request_lines
    ::SemanticLogger.flush
    @log_output.string.lines.map { |line| JSON.parse(line) }.select { |line| line["evt"] == "request" }
      .map { |line| line.values_at("method", "path", "controller", "action", "status") }
  end
end
