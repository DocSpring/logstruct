# typed: true
# frozen_string_literal: true

require "test_helper"

class FilterParametersTest < ActionDispatch::IntegrationTest
  def setup
    @log_output = StringIO.new
    ::SemanticLogger.clear_appenders!
    ::SemanticLogger.add_appender(io: @log_output, formatter: LogStruct::SemanticLogger::Formatter.new, async: false)
  end

  def test_rails_keeps_its_filter_parameters
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("password" => "hunter2")["password"]
  end

  def test_logstruct_filters_keys_from_initializers_the_way_rails_does
    # :otp and :crypt come from config/initializers/filter_parameter_logging.rb, not LogStruct's
    # defaults, and Rails matches them anywhere in a key
    Rails.logger.info(msg: "Signed in", otp_attempt: "135790", encrypted_note: "hunter2")

    ::SemanticLogger.flush
    output = @log_output.string

    assert_includes output, "Signed in"
    assert_not_includes output, "135790"
    assert_not_includes output, "hunter2"
  end

  def test_active_record_filter_attributes_still_filter
    assert_includes ActiveRecord::Base.filter_attributes, :passw
  end

  def test_request_filtered_parameters_still_filter
    get "/logging/basic", params: {password: "hunter2", name: "visible"}

    assert_response :success
    assert_equal "[FILTERED]", request.filtered_parameters["password"]
    assert_equal "visible", request.filtered_parameters["name"]
  end

  def test_request_log_shows_rails_filtered_values_as_filtered
    get "/logging/basic", params: {password: "hunter2"}

    ::SemanticLogger.flush
    @log_output.rewind
    output = @log_output.read.to_s
    request_line = output.lines.find { |line| line.include?('"evt":"request"') }

    assert request_line, "Expected a request log line. Output:\n#{output}"
    assert_not_includes output, "hunter2"
    assert_equal "[FILTERED]", JSON.parse(request_line).dig("params", "password")
  end
end
