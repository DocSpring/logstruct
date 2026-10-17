# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStruct::ParamsErrorsTest < Minitest::Test
  ParamsErrors = LogStruct::ParamsErrors

  def test_an_unrelated_error_keeps_its_messages
    error = assert_raises(RuntimeError) do
      raise IOError, "connection lost"
    rescue IOError
      raise "Import failed"
    end

    assert_equal ["Import failed", "connection lost"], ParamsErrors.messages(error)
    assert_empty ParamsErrors.replacements(error)
  end

  def test_a_wrapped_params_error_is_replaced_before_the_cause_inside_its_message
    error = assert_raises(ActionController::BadRequest) do
      Rack::Utils.parse_nested_query("password=%zz-synthetic-raw-secret")
    rescue Rack::Utils::InvalidParameterError => e
      raise ActionController::BadRequest, "Invalid request parameters: #{e.message}"
    end
    text = "#{error.class}: #{error.message}\nCause: #{error.cause&.class}: #{error.cause&.message}"

    ParamsErrors.replacements(error).each { |quoted, logged| text = text.gsub(quoted, logged) }

    expected = "ActionController::BadRequest: Invalid request parameters\n" \
      "Cause: Rack::QueryParser::InvalidParameterError: #{ParamsErrors::CAUSE_MESSAGE_LEFT_OUT}"

    assert_equal expected, text
  end
end
