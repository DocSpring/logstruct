# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/configuration"
require "log_struct/error_handling_mode"

module LogStruct
  class ConfigurationTest < Minitest::Test
    def setup
      @config = Configuration.new
    end

    # -------------------------------------------------------------------------------------
    # Error Handling Tests
    # -------------------------------------------------------------------------------------

    def test_default_error_handling_modes
      assert_equal ErrorHandlingMode::Log, @config.error_handling.type_errors
      assert_equal ErrorHandlingMode::Log, @config.error_handling.logstruct_errors
      assert_equal ErrorHandlingMode::Log, @config.error_handling.standard_errors
    end

    def test_error_handling_modes_can_be_configured_individually
      @config.error_handling.type_errors = ErrorHandlingMode::Ignore
      @config.error_handling.logstruct_errors = ErrorHandlingMode::Report
      @config.error_handling.standard_errors = ErrorHandlingMode::RaiseError

      assert_equal ErrorHandlingMode::Ignore, @config.error_handling.type_errors
      assert_equal ErrorHandlingMode::Report, @config.error_handling.logstruct_errors
      assert_equal ErrorHandlingMode::RaiseError, @config.error_handling.standard_errors
    end

    def test_error_handling_exception_reporting_handler
      handler = ->(e) { puts e.message }
      @config.error_handling.exception_reporting_handler = handler

      assert_equal handler, @config.error_handling.exception_reporting_handler
    end

    # -------------------------------------------------------------------------------------
    # Integration Tests
    # -------------------------------------------------------------------------------------

    def test_default_integration_settings
      assert @config.integrations.lograge_enabled
      assert @config.integrations.emails_enabled
    end

    def test_integration_settings_can_be_configured
      @config.integrations.lograge_enabled = false
      @config.integrations.emails_enabled = false

      assert_not @config.integrations.lograge_enabled
      assert_not @config.integrations.emails_enabled
    end

    # -------------------------------------------------------------------------------------
    # Filter Tests
    # -------------------------------------------------------------------------------------

    def test_default_filter_settings
      assert @config.filters.filter_enabled
      assert @config.filters.filter_emails
      assert @config.filters.filter_phone_numbers
      assert @config.filters.filter_credit_cards
      assert_empty @config.filters.filtered_keys
      assert_empty @config.filters.hashed_keys
      assert_equal "YOUR-SALT-HERE", @config.filters.hash_salt
      assert_equal 8, @config.filters.hash_length
    end

    def test_filter_settings_can_be_configured
      @config.filters.filter_enabled = false
      @config.filters.filter_emails = false
      @config.filters.filter_phone_numbers = false
      @config.filters.filter_credit_cards = false
      @config.filters.filtered_keys = [:password, :secret]
      @config.filters.hashed_keys = [:email, :phone]
      @config.filters.hash_salt = "test-salt"
      @config.filters.hash_length = 16

      assert_not @config.filters.filter_enabled
      assert_not @config.filters.filter_emails
      assert_not @config.filters.filter_phone_numbers
      assert_not @config.filters.filter_credit_cards
      assert_equal [:password, :secret], @config.filters.filtered_keys
      assert_equal [:email, :phone], @config.filters.hashed_keys
      assert_equal "test-salt", @config.filters.hash_salt
      assert_equal 16, @config.filters.hash_length
    end

    # -------------------------------------------------------------------------------------
    # Environment Tests
    # -------------------------------------------------------------------------------------

    def test_default_environment_settings
      assert_equal [:development, :test], @config.local_environments
      assert_equal [:development, :test, :staging, :production], @config.environments
    end

    def test_environment_settings_can_be_configured
      @config.local_environments = [:development]
      @config.environments = [:production]

      assert_equal [:development], @config.local_environments
      assert_equal [:production], @config.environments
    end

    # -------------------------------------------------------------------------------------
    # Untyped Configuration API Tests
    # -------------------------------------------------------------------------------------

    def test_untyped_error_handling_configuration
      untyped = Configuration::Untyped.new(@config)
      untyped.error_handling.configure(
        type_errors: :ignore,
        logstruct_errors: :report,
        standard_errors: :raise_error
      )

      assert_equal ErrorHandlingMode::Ignore, @config.error_handling.type_errors
      assert_equal ErrorHandlingMode::Report, @config.error_handling.logstruct_errors
      assert_equal ErrorHandlingMode::RaiseError, @config.error_handling.standard_errors
    end

    def test_untyped_integration_configuration
      untyped = Configuration::Untyped.new(@config)
      untyped.integrations.configure(
        lograge: false,
        emails: false
      )

      assert_not @config.integrations.lograge_enabled
      assert_not @config.integrations.emails_enabled
    end

    def test_untyped_filter_configuration
      untyped = Configuration::Untyped.new(@config)
      untyped.filters.configure(
        filter_enabled: false,
        filter_emails: false,
        filter_phone_numbers: false,
        filter_credit_cards: false,
        filtered_keys: [:password, :secret],
        hashed_keys: [:email, :phone],
        hash_salt: "test-salt",
        hash_length: 16
      )

      assert_not @config.filters.filter_enabled
      assert_not @config.filters.filter_emails
      assert_not @config.filters.filter_phone_numbers
      assert_not @config.filters.filter_credit_cards
      assert_equal [:password, :secret], @config.filters.filtered_keys
      assert_equal [:email, :phone], @config.filters.hashed_keys
      assert_equal "test-salt", @config.filters.hash_salt
      assert_equal 16, @config.filters.hash_length
    end

    def test_untyped_raises_for_unknown_settings
      untyped = Configuration::Untyped.new(@config)

      assert_raises(ArgumentError) { untyped.error_handling.configure(unknown: :ignore) }
      assert_raises(ArgumentError) { untyped.integrations.configure(unknown: false) }
      assert_raises(ArgumentError) { untyped.filters.configure(unknown: false) }
    end
  end
end
