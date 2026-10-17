# typed: true
# frozen_string_literal: true

require "test_helper"

class SecurityErrorsTest < ActionDispatch::IntegrationTest
  def setup
    @io = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @io, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_csrf_errors_are_logged_once_and_rails_responds_as_usual
    post "/security/submit", params: {name: "visible"}, headers: {"HTTP_REFERER" => "https://app.example.com/form?token=t1"}

    assert_response :unprocessable_entity
    lines = security_lines("csrf_violation")

    assert_equal 1, lines.size, @io.string
    assert_equal ["/security/submit", "POST", "https://app.example.com/form"], lines.first.values_at("path", "method", "referer")
  end

  def test_ip_spoofing_errors_are_logged_once_where_rails_raises_them
    headers = {"HTTP_CLIENT_IP" => "1.1.1.1", "HTTP_X_FORWARDED_FOR" => "2.2.2.2"}

    # Rails' check runs only where remote_ip is read
    get "/health", headers: headers

    assert_response :success
    assert_empty security_lines("ip_spoof")

    assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError) do
      get "/security/remote_ip", headers: headers
    end
    lines = security_lines("ip_spoof")

    assert_equal 1, lines.size, @io.string
    # The test app scrubs IP addresses
    assert_equal ["/security/remote_ip", "[IP]", "[IP]"], lines.first.values_at("path", "client_ip", "x_forwarded_for")
  end

  private

  def security_lines(event)
    ::SemanticLogger.flush
    @io.string.lines.filter_map do |line|
      parsed = JSON.parse(line)
      parsed if parsed["src"] == "security" && parsed["evt"] == event
    rescue JSON::ParserError
      nil
    end
  end
end
