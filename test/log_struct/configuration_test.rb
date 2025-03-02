# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class ConfigurationTest < Minitest::Test
    include TestHelper

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
      assert_equal "l0g5t0p", @config.email_hash_salt
      assert_equal 12, @config.email_hash_length
      assert_nil @config.lograge_custom_options
      assert_nil @config.log_scrubbing_handler
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

    def test_custom_log_scrubbing_handler
      # Set a custom scrubbing handler
      custom_scrubber = ->(msg) { "SCRUBBED: #{msg}" }
      @config.log_scrubbing_handler = custom_scrubber

      # Verify the handler is set correctly
      assert_equal custom_scrubber, @config.log_scrubbing_handler
      assert_equal "SCRUBBED: test message", @config.log_scrubbing_handler.call("test message")
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
      @config.email_hash_salt = "custom_salt"

      assert_equal "custom_salt", @config.email_hash_salt

      @config.email_hash_length = 8

      assert_equal 8, @config.email_hash_length
    end
  end
end
