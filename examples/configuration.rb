# typed: strict
# frozen_string_literal: true

require "log_struct"

# Basic configuration example for LogStruct
# This shows how to configure the main settings with Sorbet type checking
module Examples
  extend T::Sig

  sig { void }
  def self.configuration_examples
    # rubocop:disable Layout/EmptyLinesAroundBlockBody
    # ----------------------------------------------------------
    # BEGIN CODE EXAMPLE: basic_configuration
    # ----------------------------------------------------------
    LogStruct.configure do |config|

      # your configuration here

    end
    # ----------------------------------------------------------
    # END CODE EXAMPLE: basic_configuration
    # ----------------------------------------------------------
    # rubocop:enable Layout/EmptyLinesAroundBlockBody

    LogStruct.configure do |config|
      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: environment_configuration
      # ----------------------------------------------------------
      config.environments = [:test, :production]

      # LogStruct will raise errors in local environments,
      # and log or report errors in production.
      # (This can be configured with config.error_handling_modes)
      config.local_environments = [:development, :test]
      # ----------------------------------------------------------
      # END CODE EXAMPLE: environment_configuration
      # ----------------------------------------------------------

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
      config.integrations.enable_sorbet_error_handlers = true

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

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: error_handling_modes
      # ----------------------------------------------------------
      # Configure error handling modes
      modes = config.error_handling_modes
      modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
      modes.security_errors = LogStruct::ErrorHandlingMode::Report
      modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction
      modes.type_checking_errors = LogStruct::ErrorHandlingMode::Raise

      # Available error handling modes:
      # ------------------------------------------------------------
      # ::Ignore          # Completely ignore errors
      # ::Log             # Log errors but don't report them
      # ::LogProduction   # Log in production, raise in development
      # ::Report          # Log and report errors to error service
      # ::Raise           # Always raise errors
      # ----------------------------------------------------------
      # END CODE EXAMPLE: error_handling_modes
      # ----------------------------------------------------------
    end
  end
end
