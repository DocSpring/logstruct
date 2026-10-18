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
