# typed: false
# frozen_string_literal: true

require "test_helper"
require "log_struct/configuration"
require "log_struct/error_handling_mode"

module LogStruct
  class ConfigurationTest < ActiveSupport::TestCase
    def setup
      @config = Configuration.new
    end

    def test_default_values
      # Test default values for boolean flags
      assert @config.enabled
      assert @config.lograge_enabled
      assert @config.actionmailer_integration_enabled
      assert @config.host_authorization_enabled
      assert @config.activejob_integration_enabled
      assert @config.rack_middleware_enabled
      assert @config.sidekiq_integration_enabled
      assert @config.shrine_integration_enabled
      assert @config.active_storage_integration_enabled
      assert @config.carrierwave_integration_enabled

      # Test default values for log scrubbing options
      assert @config.filter_emails
      assert @config.filter_url_passwords
      assert @config.filter_credit_cards
      assert @config.filter_phones
      assert @config.filter_ssns
      assert_not @config.filter_ips
      assert_not @config.filter_macs

      # Test default values for other settings
      assert_equal "l0g5t0p", @config.hash_salt
      assert_equal 12, @config.hash_length
      assert_nil @config.lograge_custom_options
      assert_nil @config.string_scrubbing_handler
    end

    def test_exception_reporting_handler
      # The default handler should be a proc
      assert_instance_of Proc, @config.exception_reporting_handler

      # Create a test exception and context
      error = StandardError.new("Test error")
      context = {user_id: 123}

      # Mock Rails.logger to verify the handler calls it
      logger_mock = Minitest::Mock.new
      logger_mock.expect(:error, nil, [Hash])

      Rails.stub(:logger, logger_mock) do
        @config.exception_reporting_handler.call(error, context)
      end

      assert_mock logger_mock
    end

    def test_custom_exception_reporting_handler
      # Set a custom handler
      custom_handler_called = false
      custom_handler = ->(error, context) {
        custom_handler_called = true

        assert_instance_of StandardError, error
        assert_equal({user_id: 123}, context)
      }

      @config.exception_reporting_handler = custom_handler

      # Call the handler
      @config.exception_reporting_handler.call(StandardError.new("Test"), {user_id: 123})

      # Verify the custom handler was called
      assert custom_handler_called
    end

    def test_custom_string_scrubbing_handler
      # Set a custom scrubbing handler
      custom_scrubber = ->(msg) { "SCRUBBED: #{msg}" }
      @config.string_scrubbing_handler = custom_scrubber

      # Verify the handler is set correctly
      assert_equal custom_scrubber, @config.string_scrubbing_handler
      assert_equal "SCRUBBED: test message", @config.string_scrubbing_handler.call("test message")
    end

    def test_custom_lograge_options
      # Set custom lograge options
      custom_options = ->(event, options) { {custom: "value"} }
      @config.lograge_custom_options = custom_options

      # Verify the options are set correctly
      assert_equal custom_options, @config.lograge_custom_options
    end

    def test_toggle_settings
      # Test toggling boolean settings
      @config.enabled = false

      assert_not @config.enabled

      @config.filter_ips = true

      assert @config.filter_ips

      @config.sidekiq_integration_enabled = false

      assert_not @config.sidekiq_integration_enabled
    end

    def test_email_hash_settings
      # Test changing email hash settings
      @config.hash_salt = "custom_salt"

      assert_equal "custom_salt", @config.hash_salt

      @config.hash_length = 16

      assert_equal 16, @config.hash_length
    end

    def test_default_error_handling_modes
      assert_equal ErrorHandlingMode::LogProduction, @config.error_handling[:type_errors]
      assert_equal ErrorHandlingMode::LogProduction, @config.error_handling[:logstruct_errors]
      assert_equal ErrorHandlingMode::Raise, @config.error_handling[:standard_errors]
    end

    def test_setting_individual_error_handling_mode
      @config.error_handling[:type_errors] = :ignore

      assert_equal ErrorHandlingMode::Ignore, @config.error_handling[:type_errors]
    end

    def test_setting_multiple_error_handling_modes
      @config.error_handling = {
        type_errors: :ignore,
        logstruct_errors: :raise
      }

      assert_equal ErrorHandlingMode::Ignore, @config.error_handling[:type_errors]
      assert_equal ErrorHandlingMode::Raise, @config.error_handling[:logstruct_errors]
      assert_equal ErrorHandlingMode::Raise, @config.error_handling[:standard_errors] # Default preserved
    end

    def test_setting_invalid_error_handling_mode
      error = assert_raises(ArgumentError) do
        @config.error_handling[:type_errors] = :invalid_mode
      end

      assert_match(/Invalid error handling mode: :invalid_mode/, error.message)
    end

    def test_setting_invalid_error_handling_modes
      error = assert_raises(ArgumentError) do
        @config.error_handling = {
          type_errors: :ignore,
          logstruct_errors: :invalid_mode
        }
      end

      assert_match(/Invalid error handling mode: :invalid_mode/, error.message)
    end

    def test_configure_block_with_error_handling
      LogStruct.configure do |config|
        config.error_handling[:type_errors] = :ignore
      end

      assert_equal ErrorHandlingMode::Ignore, LogStruct.config.error_handling[:type_errors]
    end

    def test_configure_block_with_multiple_error_handling_modes
      LogStruct.configure do |config|
        config.error_handling = {
          type_errors: :ignore,
          logstruct_errors: :raise
        }
      end

      assert_equal ErrorHandlingMode::Ignore, LogStruct.config.error_handling[:type_errors]
      assert_equal ErrorHandlingMode::Raise, LogStruct.config.error_handling[:logstruct_errors]
      assert_equal ErrorHandlingMode::Raise, LogStruct.config.error_handling[:standard_errors] # Default preserved
    end
  end
end
