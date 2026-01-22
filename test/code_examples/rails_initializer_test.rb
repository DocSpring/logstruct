# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class RailsInitializerTest < ActiveSupport::TestCase
      def setup
        # Save original Rails.env to restore later
        @original_env = Rails.env
      end

      def teardown
        # Restore original Rails.env
        Rails.env = @original_env
      end

      def test_rails_initializer
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
            :email, :email_address
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
            params = event.payload[:params]
            params = params&.except(*Rails.application.config.filter_parameters)
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

        # Test in development environment
        Rails.env = ActiveSupport::StringInquirer.new("development")
        LogStruct.configure do |config|
          config.enabled = !Rails.env.test?

          # Configure error handling based on environment
          if Rails.env.production?
            config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
            config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
          else
            config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Raise
            config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Raise
          end
        end

        # Verify proper configuration for development
        assert LogStruct.configuration.enabled
        assert_equal LogStruct::ErrorHandlingMode::Raise,
          LogStruct.configuration.error_handling_modes.security_errors
        assert_equal LogStruct::ErrorHandlingMode::Raise,
          LogStruct.configuration.error_handling_modes.logstruct_errors

        # Test in production environment
        Rails.env = ActiveSupport::StringInquirer.new("production")
        LogStruct.configure do |config|
          config.enabled = !Rails.env.test?

          # Configure error handling based on environment
          if Rails.env.production?
            config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
            config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Log
          else
            config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Raise
            config.error_handling_modes.logstruct_errors = LogStruct::ErrorHandlingMode::Raise
          end
        end

        # Verify proper configuration for production
        assert LogStruct.configuration.enabled
        assert_equal LogStruct::ErrorHandlingMode::Report,
          LogStruct.configuration.error_handling_modes.security_errors
        assert_equal LogStruct::ErrorHandlingMode::Log,
          LogStruct.configuration.error_handling_modes.logstruct_errors
      end
    end
  end
end
