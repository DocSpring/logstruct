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
          # Filter more keys, as well as the defaults (password, token, secret, credentials, auth, ...).
          # Keys match by their words, so :account_number also filters accountNumber and Account-Number.
          config.filters.filter_keys += [:account_number, :routing_number]

          # Log a hash of these values instead of only filtering them (default: email, email_address)
          config.filters.filter_keys_with_hashes += [:username]

          # Sensitive data in every string
          config.filters.credit_card_numbers = true  # Filter credit card numbers
          config.filters.email_addresses = true      # Filter email addresses
          config.filters.ip_addresses = false        # Filter IP addresses (off by default)
          config.filters.mac_addresses = false       # Filter MAC addresses (off by default)
          config.filters.phone_numbers = true        # Filter phone numbers
          config.filters.ssns = true                 # Filter social security numbers
          config.filters.url_passwords = true        # Filter passwords in URLs

          # More rules for key names, beside the default pattern for sensitive keys
          config.filters.filter_matchers << LogStruct::ConfigStruct::FilterMatcher.new(
            callable: ->(key, _value) { key.start_with?("internal_") },
            label: "internal prefix"
          )

          # Rules that need a key's path from the line's top-level field, or the parameters around it.
          # Rails' dotted filter_parameters (like "card.number") become path matchers at boot.
          config.filters.path_matchers << LogStruct::ConfigStruct::PathFilterMatcher.new(
            callable: ->(path, _value, _root) { path.last(2) == ["bank", "number"] },
            label: "bank account numbers"
          )

          # The HMAC key for hashed values. Default: a key derived from the Rails app's secret_key_base
          config.filters.hash_salt = ENV["LOGSTRUCT_HASH_KEY"]

          # How many hex characters of each hash to log (default: 16)
          config.filters.hash_length = 16
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: filter_configuration
        # ----------------------------------------------------------

        # Verify filter configurations are applied, on top of the defaults
        filters = LogStruct.configuration.filters

        assert_includes filters.filter_keys, :password
        assert_includes filters.filter_keys, :account_number
        assert_equal %i[email email_address username], filters.filter_keys_with_hashes
        assert filters.credit_card_numbers
        assert filters.email_addresses
        assert filters.phone_numbers
        assert filters.ssns
        assert filters.url_passwords
        refute filters.ip_addresses
        refute filters.mac_addresses
        assert_includes filters.filter_matchers.map(&:label), "default_sensitive_pattern"
        assert_includes filters.filter_matchers.map(&:label), "internal prefix"
        assert LogStruct::ParamFilters.should_filter_key?("accountNumber")
        assert LogStruct::ParamFilters.should_filter_key?("internal_note")
        assert LogStruct::ParamFilters.should_filter_key?("number", "1", path: ["params", "bank", "number"])
        assert_equal 16, filters.hash_length
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
