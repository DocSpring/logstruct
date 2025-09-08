# typed: strict

# Configure LogStruct
LogStruct.configure do |config|
  # Specify which environments to enable in
  config.enabled_environments = [:development, :test, :production]

  # Specify which environments are considered local/development
  config.local_environments = [:development, :test]

  # Configure integrations
  config.integrations.enable_lograge = true
  config.integrations.enable_actionmailer = true
  config.integrations.enable_activejob = true
  config.integrations.enable_rack_error_handler = true
  config.integrations.enable_sidekiq = !!defined?(Sidekiq)
  config.integrations.enable_shrine = !!defined?(Shrine)
  config.integrations.enable_carrierwave = !!defined?(CarrierWave)
  config.integrations.enable_activestorage = true

  # Configure string scrubbing filters
  config.filters.email_addresses = true
  config.filters.url_passwords = true
  config.filters.credit_card_numbers = true
  config.filters.phone_numbers = true
  config.filters.ssns = true
  config.filters.ip_addresses = true
  config.filters.mac_addresses = true

  # Configure error handling modes
  config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
  config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
  config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::LogProduction
end
