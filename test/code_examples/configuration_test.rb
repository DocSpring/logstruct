# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class ConfigurationTest < ActiveSupport::TestCase
      def test_basic_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: basic_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # your configuration here
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_configuration
        # ----------------------------------------------------------

        # Simply assert that we can configure LogStruct
        assert_instance_of LogStruct::Configuration, LogStruct.configuration
      end

      def test_environment_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: environment_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          config.enabled_environments = [:test, :production]

          # LogStruct will raise errors in local environments,
          # and log or report errors in production.
          # (This can be configured with config.error_handling_modes)
          config.local_environments = [:development, :test]
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: environment_configuration
        # ----------------------------------------------------------

        # Verify configuration is applied
        assert_equal [:test, :production], LogStruct.configuration.enabled_environments
        assert_equal [:development, :test], LogStruct.configuration.local_environments
      end

      def test_integrations_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: integrations_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Enable/disable specific integrations
          config.integrations.enable_actionmailer = true
          config.integrations.enable_active_model_serializers = true
          config.integrations.enable_activejob = true
          config.integrations.enable_activestorage = true
          config.integrations.enable_ahoy = true
          config.integrations.enable_carrierwave = true
          config.integrations.enable_dotenv = true
          config.integrations.enable_goodjob = true
          config.integrations.enable_host_authorization = true
          config.integrations.enable_lograge = true
          config.integrations.enable_rack_error_handler = true
          config.integrations.enable_semantic_logger = true
          config.integrations.enable_shrine = true
          config.integrations.enable_sidekiq = true
          config.integrations.enable_puma = true
          config.integrations.enable_sorbet_error_handlers = true
          config.integrations.enable_sql_logging = true

          # Configure custom options for Lograge
          config.integrations.lograge_custom_options = ->(event, _) {
            {
              # Add custom fields to your Lograge output
              user_id: event.payload[:user_id],
              correlation_id: event.payload[:correlation_id]
            }
          }
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: integrations_configuration
        # ----------------------------------------------------------

        LogStruct.configure do |config|
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: sorbet_error_handlers_configuration
          # ----------------------------------------------------------
          config.integrations.enable_sorbet_error_handlers = true

          # This configures the following error handlers for Sorbet:
          # - T::Configuration.inline_type_error_handler
          # - T::Configuration.call_validation_error_handler
          # - T::Configuration.sig_builder_error_handler
          # - T::Configuration.sig_validation_error_handler
          # ----------------------------------------------------------
          # END CODE EXAMPLE: sorbet_error_handlers_configuration
          # ----------------------------------------------------------
        end

        # Verify integration configurations are applied
        assert LogStruct.configuration.integrations.enable_actionmailer
        assert LogStruct.configuration.integrations.enable_activejob
        assert LogStruct.configuration.integrations.enable_activestorage
        assert LogStruct.configuration.integrations.enable_carrierwave
        assert LogStruct.configuration.integrations.enable_host_authorization
        assert LogStruct.configuration.integrations.enable_lograge
        assert LogStruct.configuration.integrations.enable_rack_error_handler
        assert LogStruct.configuration.integrations.enable_shrine
        assert LogStruct.configuration.integrations.enable_sidekiq
        assert LogStruct.configuration.integrations.enable_sorbet_error_handlers

        # Verify the lograge custom options proc is set
        assert_kind_of Proc, LogStruct.configuration.integrations.lograge_custom_options
      end

      def test_filter_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: filter_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Configure which params should be filtered
          config.filters.filter_keys = [
            :password, :password_confirmation, :token, :secret,
            :credit_card, :ssn, :social_security
          ]

          # Configure which params should include hashes for values
          config.filters.filter_keys_with_hashes = [
            :email, :email_address
          ]

          # Configure sensitive data filtering for all strings
          config.filters.credit_card_numbers = true  # Filter credit card numbers
          config.filters.email_addresses = true      # Filter email addresses
          config.filters.ip_addresses = false        # Filter IP addresses (off by default)
          config.filters.mac_addresses = false       # Filter MAC addresses (off by default)
          config.filters.phone_numbers = true        # Filter phone numbers
          config.filters.ssns = true                 # Filter social security numbers
          config.filters.url_passwords = true        # Filter passwords in URLs

          # Configure the salt used for hashing filtered email addresses
          config.filters.hash_salt = ENV.fetch("EMAIL_HASH_SALT", "test_salt")

          # Configure the length of hash output for filtered emails (default: 12)
          config.filters.hash_length = 12
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: filter_configuration
        # ----------------------------------------------------------

        # Verify filter configurations are applied
        assert_includes LogStruct.configuration.filters.filter_keys, :password
        assert_includes LogStruct.configuration.filters.filter_keys_with_hashes, :email
        assert LogStruct.configuration.filters.credit_card_numbers
        assert LogStruct.configuration.filters.email_addresses
        assert LogStruct.configuration.filters.phone_numbers
        assert LogStruct.configuration.filters.ssns
        assert LogStruct.configuration.filters.url_passwords
        refute LogStruct.configuration.filters.ip_addresses
        refute LogStruct.configuration.filters.mac_addresses
        assert_equal LogStruct.configuration.filters.hash_salt, LogStruct.configuration.filters.hash_salt
        assert_equal 12, LogStruct.configuration.filters.hash_length
      end

      def test_error_handling_modes
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: error_handling_modes
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Configure error handling modes
          modes = config.error_handling_modes

          modes.type_checking_errors = LogStruct::ErrorHandlingMode::ReportProduction
          modes.logstruct_errors = LogStruct::ErrorHandlingMode::ReportProduction
          modes.security_errors = LogStruct::ErrorHandlingMode::Report
          modes.standard_errors = LogStruct::ErrorHandlingMode::Raise
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: error_handling_modes
        # ----------------------------------------------------------

        # Verify error handling modes are applied
        assert_equal LogStruct::ErrorHandlingMode::ReportProduction,
          LogStruct.configuration.error_handling_modes.type_checking_errors
        assert_equal LogStruct::ErrorHandlingMode::ReportProduction,
          LogStruct.configuration.error_handling_modes.logstruct_errors
        assert_equal LogStruct::ErrorHandlingMode::Report,
          LogStruct.configuration.error_handling_modes.security_errors
        assert_equal LogStruct::ErrorHandlingMode::Raise,
          LogStruct.configuration.error_handling_modes.standard_errors
      end
    end
  end
end
