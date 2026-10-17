# typed: true
# frozen_string_literal: true

require "test_helper"

class ErrorHandlingTest < Minitest::Test
  def setup
    @original_config = LogStruct.config
    LogStruct.configuration = LogStruct::Configuration.new
  end

  def teardown
    LogStruct.configuration = @original_config
  end

  def test_error_handling_mode_for_returns_standard_errors
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Log
    mode = LogStruct.error_handling_mode_for(LogStruct::Source::App)

    assert_equal LogStruct::ErrorHandlingMode::Log, mode
  end

  def test_handle_exception_ignore
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Ignore
    error = RuntimeError.new("ignore me")

    LogStruct.stub(:error, proc { flunk("should not log in ignore mode") }) do
      LogStruct.handle_exception(error, source: LogStruct::Source::App)
    end
  end

  def test_a_reporter_that_raises_is_logged_and_the_error_is_handled_as_before
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    LogStruct.config.error_reporting_handler = ->(_error, _context, _source) { raise Timeout::Error, "reporter timed out" }
    logged = []

    LogStruct.stub(:error, ->(entry) { logged << entry }) do
      LogStruct.handle_exception(RuntimeError.new("boom"), source: LogStruct::Source::App)
    end

    expected = [
      [LogStruct::Source::App, RuntimeError, "boom", nil],
      [LogStruct::Source::Internal, Timeout::Error, "The error reporter raised while reporting RuntimeError", "reporter timed out"]
    ]

    assert_equal expected, logged.map { |entry| [entry.source, entry.error_class, entry.message, entry.error_message] }
  end

  def test_handle_exception_raise
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Raise
    error = RuntimeError.new("boom")

    assert_raises(RuntimeError) do
      LogStruct.handle_exception(error, source: LogStruct::Source::App)
    end
  end

  def test_handle_exception_log
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Log
    error = RuntimeError.new("log me")
    logged = T.let([], T::Array[LogStruct::Log::Error])

    LogStruct.stub(:error, ->(log) { logged << log }) do
      LogStruct.handle_exception(error, source: LogStruct::Source::App)
    end

    assert_equal 1, logged.length
    log_entry = T.must(logged.first)

    assert_equal "log me", log_entry.message
  end

  def test_handle_exception_report
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    error = RuntimeError.new("report me")
    logged = []
    reported = []

    LogStruct.stub(:error, ->(log) { logged << log }) do
      LogStruct::MultiErrorReporter.stub(:report_error, ->(_err, _ctx) { reported << true }) do
        LogStruct.handle_exception(error, source: LogStruct::Source::App)
      end
    end

    assert_equal 1, logged.length
    assert_equal [true], reported
  end

  def test_reporters_get_the_context_filtered_and_scrubbed
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    reported = T.let([], T::Array[T.untyped])
    context = {password: "hunter2", to: ["ada@example.com"], path: "/reset?token=abc123"}

    LogStruct.stub(:error, ->(_log) {}) do
      LogStruct::MultiErrorReporter.stub(:report_error, ->(_err, ctx) { reported << ctx }) do
        LogStruct.handle_exception(RuntimeError.new("report me"), source: LogStruct::Source::App, context: context)
      end
    end

    reported_context = T.must(reported.first)

    assert_equal({_filtered: {_class: String}}, reported_context[:password])
    assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, reported_context[:to].first)
    assert_equal "/reset?token=[FILTERED]", reported_context[:path]
    # The caller's context is left as it was
    assert_equal "hunter2", context[:password]
  end

  def test_custom_reporting_handlers_get_the_filtered_context
    reported = []
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    LogStruct.config.error_reporting_handler = ->(_error, ctx, _source) { reported << ctx }

    LogStruct.stub(:error, ->(_log) {}) do
      LogStruct.handle_exception(RuntimeError.new("report me"), source: LogStruct::Source::App, context: {api_key: "k1"})
    end

    assert_equal [{api_key: {_filtered: {_class: String}}}], reported
  end

  def test_handle_exception_log_production_raises_when_not_production
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction
    error = RuntimeError.new("prod log")

    LogStruct.stub(:is_production?, false) do
      assert_raises(RuntimeError) do
        LogStruct.handle_exception(error, source: LogStruct::Source::App)
      end
    end
  end

  def test_handle_exception_log_production_logs_in_production
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction
    error = RuntimeError.new("prod log")
    logged = []

    LogStruct.stub(:is_production?, true) do
      LogStruct.stub(:error, ->(log) { logged << log }) do
        LogStruct.handle_exception(error, source: LogStruct::Source::App)
      end
    end

    assert_equal 1, logged.length
  end

  def test_type_checking_errors_are_logged_and_reported_in_production_by_default
    error = TypeError.new("Expected type String, got type Integer")
    logged = []
    reported = []
    LogStruct.config.error_reporting_handler = ->(e, _context, source) { reported << [e, source] }

    LogStruct.stub(:is_production?, true) do
      LogStruct.stub(:error, ->(log) { logged << log }) do
        LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
      end
    end

    assert_equal 1, logged.length
    assert_equal [[error, LogStruct::Source::TypeChecking]], reported
  end

  def test_handle_exception_report_without_logging
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    error = RuntimeError.new("already logged")
    logged = []
    reported = []

    LogStruct.stub(:error, ->(log) { logged << log }) do
      LogStruct::MultiErrorReporter.stub(:report_error, ->(err, _ctx) { reported << err }) do
        LogStruct.handle_exception(error, source: LogStruct::Source::App, log: false)
      end
    end

    assert_empty logged
    assert_equal [error], reported
  end

  def test_handle_exception_log_mode_without_logging_does_nothing
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Log
    logged = []

    LogStruct.stub(:error, ->(log) { logged << log }) do
      LogStruct.handle_exception(RuntimeError.new("already logged"), source: LogStruct::Source::App, log: false)
    end

    assert_empty logged
  end
end
