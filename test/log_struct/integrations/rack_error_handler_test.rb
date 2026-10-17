# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStruct::Integrations::RackErrorHandlerTest < Minitest::Test
  ErrorLines = LogStruct::Integrations::RackErrorHandler::ErrorLines
  ParseErrorLogging = LogStruct::Integrations::RackErrorHandler::ParseErrorLogging

  def test_csrf_and_ip_spoofing_errors_are_security_errors
    csrf_error = Class.new(StandardError) do
      def self.name = "ActionController::InvalidAuthenticityToken"
    end
    cross_origin_error = Class.new(StandardError) do
      def self.name = "ActionController::InvalidCrossOriginRequest"
    end

    assert ErrorLines.security_error?(csrf_error.new("csrf"))
    assert ErrorLines.security_error?(cross_origin_error.new("csrf"))
    assert ErrorLines.security_error?(ActionDispatch::RemoteIp::IpSpoofAttackError.new("spoof"))
    refute ErrorLines.security_error?(RuntimeError.new("boom"))
  end

  def test_an_unhandled_errors_status_and_cause_are_typed_fields
    error = begin
      begin
        raise IOError, "connection lost"
      rescue IOError
        raise "Import failed"
      end
    rescue => e
      e
    end
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/imports"))
    lines = []

    LogStruct.stub(:fatal, ->(line) { lines << line }) do
      ErrorLines.log_unhandled(request, ActionDispatch::ExceptionWrapper.new(ActiveSupport::BacktraceCleaner.new, error))
      # Without a backtrace cleaner, Rails gives the trace as Thread::Backtrace::Locations
      ErrorLines.log_unhandled(request, ActionDispatch::ExceptionWrapper.new(nil, error.dup))
    end

    line = T.cast(lines.fetch(0), LogStruct::Log::Error)

    assert_equal [500, "IOError", "connection lost"], [line.status, line.cause_class, line.cause_message]
    assert_nil line.additional_data
    assert_equal 2, lines.size
    assert_kind_of String, T.cast(lines.fetch(1), LogStruct::Log::Error).backtrace&.first
  end

  def test_a_body_rails_cant_parse_is_logged_as_its_size_not_its_contents
    ActionDispatch::Request.prepend(ParseErrorLogging) unless ActionDispatch::Request <= ParseErrorLogging
    output = StringIO.new
    body = '{"password":"synthetic-raw-secret",'
    env = Rack::MockRequest.env_for("/sessions", :method => "POST", :input => body, "CONTENT_TYPE" => "application/json")
    env["action_dispatch.logger"] = ::Logger.new(output)
    request = ActionDispatch::Request.new(env)

    assert_raises(ActionDispatch::Http::Parameters::ParseError) { request.request_parameters }
    assert_includes output.string, "(#{body.bytesize} bytes of application/json)"
    refute_includes output.string, "synthetic-raw-secret"
  end

  def test_errors_from_parsing_params_leave_out_the_input_the_parsers_quote
    parse_error = raised do
      JSON.parse('{"password":synthetic-raw-secret}')
    rescue JSON::ParserError
      raise ActionDispatch::Http::Parameters::ParseError, "Error occurred while parsing request parameters"
    end
    bad_request = raised do
      Rack::Utils.parse_nested_query("password=%zz-synthetic-raw-secret")
    rescue Rack::Utils::InvalidParameterError => e
      raise ActionController::BadRequest, "Invalid request parameters: #{e.message}"
    end
    rack_error = raised { Rack::Utils.parse_nested_query("password=%zz-synthetic-raw-secret") }
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/sessions", method: "POST"))
    lines = []

    LogStruct.stub(:fatal, ->(line) { lines << line }) do
      LogStruct.stub(:error, ->(line) { lines << line }) do
        [parse_error, bad_request].each do |error|
          ErrorLines.log_unhandled(request, ActionDispatch::ExceptionWrapper.new(ActiveSupport::BacktraceCleaner.new, error))
        end
        # From a middleware outside ShowExceptions that reads Rack's params
        ErrorLines.log_escaped(request, rack_error)
      end
    end

    expected = [
      ["Error occurred while parsing request parameters", "JSON::ParserError", nil],
      ["Invalid request parameters", "Rack::QueryParser::InvalidParameterError", nil],
      ["Invalid request parameters", nil, nil]
    ]

    assert_equal expected, lines.map { |line| [line.message, line.cause_class, line.cause_message] }
    refute_includes lines.map { |line| line.serialize.to_json }.join, "synthetic-raw-secret"
  end

  def test_the_middleware_logs_an_escaped_error_once_and_raises_it_again
    io = StringIO.new
    logger = Logger.new(io)
    logger.formatter = LogStruct::Formatter.new
    error = RuntimeError.new("boom")
    middleware = LogStruct::Integrations::RackErrorHandler::Middleware.new(->(_env) { raise error })
    env = Rack::MockRequest.env_for("/orders?page=2", "HTTP_REFERER" => "https://app.example.com/reset?token=t1")

    LogStruct.stub(:error, ->(line) { logger.error(line) }) do
      2.times do
        raised = assert_raises(RuntimeError) { middleware.call(env) }

        assert_same error, raised
      end
    end

    lines = io.string.lines.map { |line| JSON.parse(line) }

    assert_equal 1, lines.size
    assert_equal ["rails", "error", "RuntimeError", "boom", "/orders", "GET", "https://app.example.com/reset"],
      lines.first.values_at("src", "evt", "error_class", "msg", "path", "method", "referer")
  end

  private

  def raised
    yield

    flunk "Expected an error"
  rescue => e
    e
  end
end
