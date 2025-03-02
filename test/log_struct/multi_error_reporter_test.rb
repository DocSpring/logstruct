# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class MultiErrorReporterTest < Minitest::Test
    def setup
      # Create a test exception and context
      @exception = StandardError.new("Test error")
      @context = {user_id: 123, action: "test"}

      # Reset the error reporter before each test
      MultiErrorReporter.instance_variable_set(:@error_reporter, nil)

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

      # Mock Sentry.capture_exception
      sentry_mock = Minitest::Mock.new
      sentry_mock.expect(:capture_exception, nil, [@exception, {extra: @context}])

      ::Sentry.stub(:capture_exception, sentry_mock) do
        MultiErrorReporter.report_exception(@exception, @context)
      end

      assert_mock sentry_mock
      assert_equal ErrorReporter::Sentry, MultiErrorReporter.error_reporter
    end

    def test_report_exception_with_sentry_error_fallback
      # Skip if Sentry is not defined
      skip "Sentry is not available" unless defined?(::Sentry)

      # Force Sentry to raise an error
      ::Sentry.stub(:capture_exception, ->(_exception, _options) { raise "Sentry error" }) do
        MultiErrorReporter.report_exception(@exception, @context)
      end

      # Verify fallback logging occurred
      output = @stdout_buffer.string

      assert_not_empty output

      parsed_output = JSON.parse(output, symbolize_names: true)

      assert_equal "rails", parsed_output[:src]
      assert_equal "error", parsed_output[:evt]
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
      assert_equal ErrorReporter::Bugsnag, MultiErrorReporter.error_reporter
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
      assert_equal ErrorReporter::Rollbar, MultiErrorReporter.error_reporter
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
      assert_equal ErrorReporter::Honeybadger, MultiErrorReporter.error_reporter
    end

    def test_report_exception_with_no_service
      # Temporarily undefine all error reporting services
      original_constants = {}

      # Store and remove constants if they exist
      [:Sentry, :Bugsnag, :Rollbar, :Honeybadger].each do |const|
        if Object.const_defined?(const)
          original_constants[const] = Object.const_get(const)
          Object.send(:remove_const, const)
        end
      end

      begin
        # Reset the reporter to force reinitialization
        MultiErrorReporter.instance_variable_set(:@error_reporter, nil)
        MultiErrorReporter.report_exception(@exception, @context)

        # Verify fallback logging occurred
        output = @stdout_buffer.string

        assert_not_empty output

        parsed_output = JSON.parse(output, symbolize_names: true)

        assert_equal "rails", parsed_output[:src]
        assert_equal "error", parsed_output[:evt]
        assert_equal "StandardError", parsed_output[:error_class]
        assert_equal "Test error", parsed_output[:error_message]
        assert_equal @context, parsed_output[:context]

        # Verify the reporter was initialized to use fallback
        assert_equal ErrorReporter::RailsLogger, MultiErrorReporter.error_reporter
      ensure
        # Restore constants
        original_constants.each do |const, value|
          Object.const_set(const, value)
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
      assert_equal ErrorReporter::Sentry, MultiErrorReporter.error_reporter
    end
  end
end
