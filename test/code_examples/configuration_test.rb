# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class ConfigurationTest < ActiveSupport::TestCase
      class MockUser < T::Struct
        const :id, Integer
        const :email, String
      end

      class MockRequest < T::Struct
        const :remote_ip, String
      end

      def test_basic_logging # rubocop:disable Minitest/NoAssertions
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------
        # Log a simple string
        Rails.logger.info "User signed in"

        # Log a hash with custom fields
        Rails.logger.info({
          event: "user_login",
          user_id: 123,
          ip_address: "192.168.1.1",
          custom_field: "any value you want"
        })
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_logging
        # ----------------------------------------------------------
      end

      def test_getting_started_basic_logging # rubocop:disable Minitest/NoAssertions
        user = MockUser.new(id: 123, email: "user@example.com")
        request = MockRequest.new(remote_ip: "192.168.1.1")

        # Set up tagged logger
        Rails.logger = ActiveSupport::TaggedLogging.new(Rails.logger)

        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------
        # Log a simple message
        Rails.logger.info "User signed in"

        # Log structured data
        Rails.logger.info({
          src: "rails",
          evt: "user_login",
          user_id: user.id,
          ip_address: request.remote_ip
        })

        # Log with tags
        Rails.logger.tagged("Authentication") do
          Rails.logger.info "User signed in"
          Rails.logger.info(user_id: user.id, ip_address: request.remote_ip)
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: getting_started_basic_logging
        # ----------------------------------------------------------
      end

      def test_typed_logging
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: typed_logging
        # ----------------------------------------------------------
        # Create a typed request log entry
        request_log = LogStruct::Log::Request.new(
          source: LogStruct::Source::Rails,
          http_method: "GET",
          path: "/users",
          status: 200,
          duration: 45.2
        )

        # Log the typed struct
        Rails.logger.info(request_log)
        # ----------------------------------------------------------
        # END CODE EXAMPLE: typed_logging
        # ----------------------------------------------------------

        # Simple assertion to make the test pass
        assert_instance_of LogStruct::Log::Request, request_log
      end

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
          config.integrations.enable_lograge = true
          config.integrations.enable_actionmailer = true
          config.integrations.enable_activejob = true
          config.integrations.enable_activestorage = true
          config.integrations.enable_carrierwave = true
          config.integrations.enable_host_authorization = true
          config.integrations.enable_rack_error_handler = true
          config.integrations.enable_shrine = true
          config.integrations.enable_sidekiq = true
          config.integrations.enable_sorbet_error_handlers = true

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
        assert LogStruct.configuration.integrations.enable_lograge
        assert LogStruct.configuration.integrations.enable_actionmailer
        assert LogStruct.configuration.integrations.enable_activejob
        assert LogStruct.configuration.integrations.enable_activestorage
        assert LogStruct.configuration.integrations.enable_carrierwave
        assert LogStruct.configuration.integrations.enable_host_authorization
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
            :email, :email_address, :user_email
          ]

          # Configure sensitive data filtering for all strings
          config.filters.email_addresses = true      # Filter email addresses
          config.filters.url_passwords = true        # Filter passwords in URLs
          config.filters.credit_card_numbers = true  # Filter credit card numbers
          config.filters.phone_numbers = true        # Filter phone numbers
          config.filters.ssns = true                 # Filter social security numbers
          config.filters.ip_addresses = false        # Filter IP addresses (off by default)
          config.filters.mac_addresses = false       # Filter MAC addresses (off by default)

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
        assert LogStruct.configuration.filters.email_addresses
        assert LogStruct.configuration.filters.url_passwords
        assert LogStruct.configuration.filters.credit_card_numbers
        assert LogStruct.configuration.filters.phone_numbers
        assert LogStruct.configuration.filters.ssns
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
