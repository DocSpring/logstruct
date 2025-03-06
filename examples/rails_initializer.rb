# typed: strict
# frozen_string_literal: true

# This is an example of how you would set up LogStruct in a Rails application
# Place this in config/initializers/log_struct.rb
# ----------------------------------------------------------
# BEGIN CODE EXAMPLE: rails_initializer
# ----------------------------------------------------------
LogStruct.configure do |config|
  # Basic configuration
  config.enabled = !Rails.env.test? # Disable in test mode to speed up tests
  config.local_environments = [:development, :test]

  # Configure error handling based on environment
  if Rails.env.production?
    # In production, report serious errors to error tracking services
    config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
    config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
  else
    # In development, raise errors to see them immediately
    config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Raise
    config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Raise
  end

  # Configure sensitive data filtering
  config.filters.filter_keys = [
    :password, :password_confirmation,
    :api_key, :api_secret, :token,
    :credit_card, :card_number, :cvv
  ]

  # Add additional sensitive fields from your application
  config.filters.filter_keys_with_hashes = [
    :email, :email_address, :user_email
  ]

  # Set a unique hash salt for your application (used for email hashing)
  config.filters.hash_salt = Rails.application.credentials.log_struct_salt || SecureRandom.hex(8)

  # Configure which integrations to enable (all true by default)
  # Disable any integrations you don't need
  config.integrations.enable_lograge = true
  config.integrations.enable_actionmailer = true
  config.integrations.enable_activejob = true
  config.integrations.enable_sidekiq = !!defined?(Sidekiq)
  config.integrations.enable_shrine = !!defined?(Shrine)
  config.integrations.enable_carrierwave = !!defined?(CarrierWave)

  # Add custom fields to lograge output
  config.integrations.lograge_custom_options = ->(event, _) {
    params = event.payload[:params].except(*Rails.application.config.filter_parameters)
    {
      # Add request_id for correlation across logs
      request_id: event.payload[:headers]&.[]("X-Request-Id") || SecureRandom.uuid,
      # Add current user ID if available
      user_id: event.payload[:user_id],
      # Add params safely filtered
      params: params
    }
  }
end

# You can also access configuration directly when needed
Rails.logger.info("LogStruct enabled: #{LogStruct.config.enabled}")
# ----------------------------------------------------------
# END CODE EXAMPLE: rails_initializer
# ----------------------------------------------------------
