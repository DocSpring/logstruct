# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStruct::Integrations::RackErrorHandlerTest < Minitest::Test
  ErrorLines = LogStruct::Integrations::RackErrorHandler::ErrorLines

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
end
