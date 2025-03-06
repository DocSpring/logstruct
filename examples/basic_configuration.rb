# typed: strict
# frozen_string_literal: true

require "log_struct"

# Basic configuration example for LogStruct
# This shows how to configure the main settings with Sorbet type checking
module Examples
  extend T::Sig

  sig { void }
  def self.basic_configuration_example
    # ----------------------------------------------------------
    # BEGIN CODE EXAMPLE: basic_configuration
    # ----------------------------------------------------------
    # Configure LogStruct with a block
    LogStruct.configure do |config|
      # Enable or disable LogStruct
      config.enabled = true

      # Define which environments are considered "local" vs "production"
      # This affects error handling modes that behave differently in different environments
      config.local_environments = [:development, :test]
      config.environments = [:test, :production, :staging]

      # Configure error handling modes
      config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
      config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
      config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Raise
      config.error_handling_modes.type_checking_errors = LogStruct::ErrorHandlingMode::LogProduction

      # Configure which params should be filtered
      config.filters.filter_keys = [
        :password, :password_confirmation, :token, :secret,
        :credit_card, :ssn, :social_security
      ]

      # Configure filtering of PII in string values
      config.filters.email_addresses = true
      config.filters.phone_numbers = true
      config.filters.ssns = true
      config.filters.credit_card_numbers = true
      config.filters.url_passwords = true

      # Configure hash settings for email address filtering
      config.filters.hash_salt = "my-secret-salt"
      config.filters.hash_length = 12
    end
    # ----------------------------------------------------------
    # END CODE EXAMPLE: basic_configuration
    # ----------------------------------------------------------
  end

  # Example of configuring specific integrations
  sig { void }
  def self.integrations_configuration_example
    LogStruct.configure do |config|
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: integrations_configuration
      # ----------------------------------------------------------
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
      config.integrations.enable_sorbet_error_handler = true

      # Configure custom options for Lograge
      config.integrations.lograge_custom_options = ->(event, _) {
        {
          # Add custom fields to your Lograge output
          user_id: event.payload[:user_id],
          correlation_id: event.payload[:correlation_id]
        }
      }
      # ----------------------------------------------------------
      # END CODE EXAMPLE: integrations_configuration
      # ----------------------------------------------------------
    end
  end

  # Example of configuring sensitive data filtering
  sig { void }
  def self.filter_configuration_example
    LogStruct.configure do |config|
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: filter_configuration
      # ----------------------------------------------------------

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
      config.filters.hash_salt = ENV.fetch("EMAIL_HASH_SALT")

      # Configure the length of hash output for filtered emails (default: 12)
      config.filters.hash_length = 12
      # ----------------------------------------------------------
      # END CODE EXAMPLE: filter_configuration
      # ----------------------------------------------------------
    end
  end
end
