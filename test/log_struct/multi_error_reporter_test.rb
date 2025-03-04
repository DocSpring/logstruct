# typed: false
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

    def test_report_exception_with_sentry
      # Skip if Sentry is not defined
      skip "Sentry is not available" unless defined?(::Sentry)

      # Create a stub to assert capture_exception was called
      called = false
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
        MultiErrorReporter.report_exception(@exception, @context)
      end

      assert called, "Sentry.capture_exception should have been called"
    end

    def test_report_exception_with_sentry_error_fallback
      # Skip if Sentry is not defined
      skip "Sentry is not available" unless defined?(::Sentry)

      # Create a log mock to verify LogStruct.log was called correctly
      log_mock = Minitest::Mock.new
      LogStruct.stub(:log, log_mock) do
        # Force Sentry to raise an error
        ::Sentry.stub(:capture_exception, ->(_exception, _options) { raise "Sentry error" }) do
          # Expect log to be called with an Exception log struct with source LogStruct
          log_mock.expect(:call, nil) do |log_entry|
            assert_instance_of Log::Exception, log_entry
            assert_equal Source::LogStruct, log_entry.source
            assert_equal LogEvent::Error, log_entry.event
            true
          end

          MultiErrorReporter.report_exception(@exception, @context)
        end
      end

      # Verify our mock was called
      assert_mock log_mock
    end

    def test_report_exception_with_bugsnag
      # Skip if Bugsnag is not defined
      skip "Bugsnag is not available" unless defined?(::Bugsnag)

      report_mock = Minitest::Mock.new
      report_mock.expect(:add_metadata, nil, [:context, @context])

      # Mock Bugsnag.notify with a block
      bugsnag_mock = ->(exception, &block) {
        assert_equal @exception, exception
        block.call(report_mock)
      }

      ::Bugsnag.stub(:notify, bugsnag_mock) do
        MultiErrorReporter.report_exception(@exception, @context)
      end

      assert_mock report_mock
      assert_equal ErrorReporter::Bugsnag, MultiErrorReporter.reporter
    end

    def test_report_exception_with_rollbar
      # Skip if Rollbar is not defined
      skip "Rollbar is not available" unless defined?(::Rollbar)

      # Mock Rollbar.error
      rollbar_mock = Minitest::Mock.new
      rollbar_mock.expect(:error, nil, [@exception, @context])

      ::Rollbar.stub(:error, rollbar_mock) do
        MultiErrorReporter.report_exception(@exception, @context)
      end

      assert_mock rollbar_mock
      assert_equal ErrorReporter::Rollbar, MultiErrorReporter.reporter
    end

    def test_report_exception_with_honeybadger
      # Skip if Honeybadger is not defined
      skip "Honeybadger is not available" unless defined?(::Honeybadger)

      # Mock Honeybadger.notify
      honeybadger_mock = Minitest::Mock.new
      honeybadger_mock.expect(:notify, nil, [@exception, {context: @context}])

      ::Honeybadger.stub(:notify, honeybadger_mock) do
        MultiErrorReporter.report_exception(@exception, @context)
      end

      assert_mock honeybadger_mock
      assert_equal ErrorReporter::Honeybadger, MultiErrorReporter.reporter
    end

    def test_report_exception_with_no_service
      # Temporarily undefine all error reporting services
      original_constants = {}
      original_constants[:Sentry] = Object.send(:remove_const, :Sentry) if defined?(::Sentry)
      original_constants[:Bugsnag] = Object.send(:remove_const, :Bugsnag) if defined?(::Bugsnag)
      original_constants[:Rollbar] = Object.send(:remove_const, :Rollbar) if defined?(::Rollbar)
      original_constants[:Honeybadger] = Object.send(:remove_const, :Honeybadger) if defined?(::Honeybadger)

      begin
        # Reset the reporter to force detection with no services available
        MultiErrorReporter.instance_variable_set(:@reporter, nil)
        
        # Verify that RailsLogger is detected when no services are available
        assert_equal ErrorReporter::RailsLogger, MultiErrorReporter.reporter

        # Create a log mock to verify LogStruct.log was called correctly
        log_mock = Minitest::Mock.new
        log_mock.expect(:call, nil) do |log_entry|
          assert_instance_of Log::Exception, log_entry
          assert_equal Source::LogStruct, log_entry.source
          assert_equal "Test error", log_entry.message
          assert_equal StandardError, log_entry.err_class
          assert_equal @context, log_entry.data
          true
        end

        # This is where we actually call report_exception with our mock
        LogStruct.stub(:log, log_mock) do
          MultiErrorReporter.report_exception(@exception, @context)
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

    def test_reporter_priority_with_all_services
      # Skip if any service is not defined
      skip "Not all services are available" unless
        defined?(::Sentry) && defined?(::Bugsnag) &&
          defined?(::Rollbar) && defined?(::Honeybadger)

      # Create mocks for all services
      sentry_mock = Minitest::Mock.new
      sentry_mock.expect(:capture_exception, nil, [@exception, {extra: @context}])

      # Reset the reporter to force reinitialization
      MultiErrorReporter.instance_variable_set(:@error_reporter, nil)

      # Stub all services but only expect Sentry to be called
      ::Sentry.stub(:capture_exception, sentry_mock) do
        # These should not be called
        ::Bugsnag.stub(:notify, ->(_exception, _options) { flunk "Bugsnag should not be called" }) do
          ::Rollbar.stub(:error, ->(_exception, _context) { flunk "Rollbar should not be called" }) do
            ::Honeybadger.stub(:notify, ->(_exception, _options) { flunk "Honeybadger should not be called" }) do
              MultiErrorReporter.report_exception(@exception, @context)
            end
          end
        end
      end

      assert_mock sentry_mock
      assert_equal ErrorReporter::Sentry, MultiErrorReporter.reporter
    end
  end
end
