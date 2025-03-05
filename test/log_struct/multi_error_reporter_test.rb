# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class MultiErrorReporterTest < ActiveSupport::TestCase
    def setup
      # Create a test exception and context
      @exception = StandardError.new("Test error")
      @context = {user_id: 123, action: "test"}

      # Reset the reporter before each test
      MultiErrorReporter.instance_variable_set(:@reporter, nil)

      # Stub stdout to capture output
      @original_stdout = $stdout
      @stdout_buffer = StringIO.new
      $stdout = @stdout_buffer
    end

    def teardown
      # Restore stdout
      $stdout = @original_stdout
    end

    def test_report_error_with_sentry
      # Create a stub to assert capture_exception was called
      called = T.let(false, T::Boolean)
      capture_stub = ->(exception, options) {
        called = true

        assert_equal @exception, exception
        assert_equal({extra: @context}, options)
        nil
      }

      # Set the reporter to Sentry
      MultiErrorReporter.reporter = :sentry

      # Verify that Sentry is the current reporter
      assert_equal ErrorReporter::Sentry, MultiErrorReporter.reporter

      # Stub the Sentry method
      ::Sentry.stub(:capture_exception, capture_stub) do
        # Make the call to test
        MultiErrorReporter.report_error(@exception, @context)
      end

      assert called, "Sentry.capture_exception should have been called"
    end

    def test_report_error_with_sentry_error_fallback
      # Skip if Sentry is not defined
      skip "Sentry is not available" unless defined?(::Sentry)

      # Create a log mock to verify LogStruct.log was called correctly
      log_mock = Minitest::Mock.new
      LogStruct.stub(:log, log_mock) do
        # Force Sentry to raise an error
        ::Sentry.stub(:capture_exception, ->(_exception, _options) { raise "Sentry error" }) do
          # Expect log to be called with an Exception log struct with source LogStruct
          log_mock.expect(:call, nil) do |log_entry|
            assert_instance_of Log::Error, log_entry
            assert_equal Source::LogStruct, log_entry.source
            assert_equal LogEvent::Error, log_entry.event
            true
          end

          MultiErrorReporter.report_error(@exception, @context)
        end
      end

      # Verify our mock was called
      assert_mock log_mock
    end

    def test_report_error_with_bugsnag
      # Set the reporter explicitly for this test
      MultiErrorReporter.reporter = :bugsnag

      # Create a test class for our report mock
      report_mock_class = Class.new do
        attr_accessor :key, :data

        def add_metadata(key, data)
          @key = key
          @data = data
          @called = true
        end

        def called?
          @called || false
        end
      end

      report_mock = report_mock_class.new

      # Mock Bugsnag.notify to yield our report mock
      bugsnag_notify_block = T.let(nil, T.untyped)

      # Use Minitest stub
      ::Bugsnag.stub(:notify,
        ->(exception, &block) {
          bugsnag_notify_block = block
          block&.call(report_mock)
        }) do
        MultiErrorReporter.report_error(@exception, @context)
      end

      # Verify notification occurred
      assert bugsnag_notify_block, "Bugsnag.notify block not called"
      assert_predicate report_mock, :called?, "Report mock add_metadata not called"
      assert_equal :context, report_mock.key
      assert_equal @context, report_mock.data
      assert_equal ErrorReporter::Bugsnag, MultiErrorReporter.reporter
    end

    def test_report_error_with_rollbar
      # Set the reporter explicitly for this test
      MultiErrorReporter.reporter = :rollbar

      # Track whether Rollbar.error was called
      error_called = T.let(false, T::Boolean)
      exception_arg = T.let(nil, T.untyped)
      context_arg = T.let(nil, T.untyped)

      ::Rollbar.stub(:error,
        ->(exception, context) {
          error_called = true
          exception_arg = exception
          context_arg = context
        }) do
        MultiErrorReporter.report_error(@exception, @context)
      end

      # Verify error was called with correct args
      assert error_called, "Rollbar.error was not called"
      assert_equal @exception, exception_arg
      assert_equal @context, context_arg
      assert_equal ErrorReporter::Rollbar, MultiErrorReporter.reporter
    end

    def test_report_error_with_honeybadger
      # Set the reporter explicitly for this test
      MultiErrorReporter.reporter = :honeybadger

      # Track whether Honeybadger.notify was called
      notify_called = T.let(false, T::Boolean)
      exception_arg = T.let(nil, T.untyped)
      options_arg = T.let(nil, T.untyped)

      ::Honeybadger.stub(:notify,
        ->(exception, options) {
          notify_called = true
          exception_arg = exception
          options_arg = options
        }) do
        MultiErrorReporter.report_error(@exception, @context)
      end

      # Verify notify was called with correct args
      assert notify_called, "Honeybadger.notify was not called"
      assert_equal @exception, exception_arg
      assert_equal({context: @context}, options_arg)
      assert_equal ErrorReporter::Honeybadger, MultiErrorReporter.reporter
    end

    def test_report_error_with_no_service
      # Temporarily undefine all error reporting services
      original_constants = {}
      original_constants[:Sentry] = Object.send(:remove_const, :Sentry) if defined?(::Sentry)
      original_constants[:Bugsnag] = Object.send(:remove_const, :Bugsnag) if defined?(::Bugsnag)
      original_constants[:Rollbar] = Object.send(:remove_const, :Rollbar) if defined?(::Rollbar)
      original_constants[:Honeybadger] = Object.send(:remove_const, :Honeybadger) if defined?(::Honeybadger)

      begin
        # Force the reporter to use RailsLogger
        MultiErrorReporter.reporter = :rails_logger

        # Verify that RailsLogger is detected when no services are available
        assert_equal ErrorReporter::RailsLogger, MultiErrorReporter.reporter

        # Create a log mock to verify LogStruct.log was called correctly
        log_mock = Minitest::Mock.new
        log_mock.expect(:call, nil) do |log_entry|
          assert_instance_of Log::Error, log_entry
          assert_equal Source::LogStruct, log_entry.source
          assert_equal "Test error", log_entry.message
          assert_equal StandardError, log_entry.err_class
          assert_equal @context, log_entry.data
          true
        end

        # This is where we actually call report_error with our mock
        LogStruct.stub(:log, log_mock) do
          MultiErrorReporter.report_error(@exception, @context)
        end

        # Verify our mock was called
        assert_mock log_mock
      ensure
        # Restore constants
        original_constants.each do |const, value|
          Object.const_set(const, value) if value
        end
      end
    end
  end
end
