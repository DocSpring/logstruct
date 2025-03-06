# typed: strict
# frozen_string_literal: true

# Example showing basic configuration options for LogStruct
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
end
# ----------------------------------------------------------
# END CODE EXAMPLE: basic_configuration
# ----------------------------------------------------------