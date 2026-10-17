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
          # Filter these keys too, on top of LogStruct's defaults and Rails' filter_parameters
          config.filters.filter_keys += [:date_of_birth]

          # Log SQL queries slower than 100 ms (off by default)
          config.integrations.enable_sql_logging = true
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: basic_configuration
        # ----------------------------------------------------------

        assert_includes LogStruct.config.filters.filter_keys, :date_of_birth
        assert_includes LogStruct.config.filters.filter_keys, :password
        assert LogStruct.config.integrations.enable_sql_logging
        assert_in_delta 100.0, LogStruct.config.integrations.sql_slow_query_threshold
      end

      def test_environment_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: environment_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # The environments where LogStruct switches on for the processes it recognizes (the default)
          config.enabled_environments = [:test, :production]

          # The environments where the LogProduction and ReportProduction error modes raise instead
          # of logging, and where LogStruct also writes Rails' log file (the default)
          config.local_environments = [:development, :test]
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: environment_configuration
        # ----------------------------------------------------------

        # Verify configuration is applied
        assert_equal [:test, :production], LogStruct.configuration.enabled_environments
        assert_equal [:development, :test], LogStruct.configuration.local_environments
      end

      def test_enable_in_development
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: enable_in_development
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # config.enabled applies to every process that loads this initializer, in every
          # environment, so limit it to the environment you mean
          config.enabled = true if Rails.env.development?
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: enable_in_development
        # ----------------------------------------------------------

        # The test app runs in test, where LogStruct is already on
        assert LogStruct.config.enabled
      end

      def test_logger_settings
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: logger_settings
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # In development (when LogStruct is on there), write the same JSON as production (the
          # default). Set it to false for colored, pretty-printed lines instead.
          config.prefer_json_in_development = true
          config.enable_color_output = true

          # The colors for those lines. Types you leave out keep their default color.
          config.color_map = {key: :yellow, string: :green, number: :blue, bool: :magenta, nil: :red, name: :cyan}

          # Leave out the lines from ActionView, ActionController::RoutingError and
          # ActiveRecord::SchemaMigration (off by default)
          config.filter_noisy_loggers = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: logger_settings
        # ----------------------------------------------------------

        config = LogStruct.config

        assert config.prefer_json_in_development
        assert config.enable_color_output
        assert_equal :yellow, config.color_map&.fetch(:key)
        refute config.filter_noisy_loggers
      end

      def test_integrations_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: integrations_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Turn integrations on or off. These are the defaults: every integration is on, except SQL
          # logging. An integration does nothing unless its gem is loaded.
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
          config.integrations.enable_shrine = true
          config.integrations.enable_sidekiq = true
          config.integrations.enable_puma = true
          config.integrations.enable_sorbet_error_handlers = true
          # Logs queries slower than sql_slow_query_threshold, in place of Rails' own SQL lines
          config.integrations.enable_sql_logging = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: integrations_configuration
        # ----------------------------------------------------------

        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: integration_settings
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Add fields to request lines (see "Custom Lograge Options" below). Default: nil
          config.integrations.lograge_custom_options = ->(event, _options) { {user_id: event.payload[:user_id]} }

          # The mailer instance variables whose IDs are logged on mail lines. Default:
          config.integrations.actionmailer_id_mapping = {account: :account_id, user: :user_id}

          # With SQL logging on, log queries that take at least this many milliseconds (0 or nil logs
          # every query). Default: 100.0
          config.integrations.sql_slow_query_threshold = 100.0

          # Log SQL queries' bind values, filtered by column name. Default: false in production, true
          # elsewhere
          config.integrations.sql_log_bind_params = !Rails.env.production?
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: integration_settings
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

        # The example shows the defaults
        defaults = LogStruct::ConfigStruct::Integrations.new

        assert_equal defaults.serialize.except(:lograge_custom_options),
          LogStruct.configuration.integrations.serialize.except(:lograge_custom_options)
        assert_kind_of Proc, LogStruct.configuration.integrations.lograge_custom_options
      end

      def test_filter_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: filter_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Filter more keys, as well as the defaults (password, token, secret, credentials, auth, ...).
          # Keys match by their words, so :account_number also filters accountNumber and
          # Account-Number, but not longer keys like account_number_last4.
          config.filters.filter_keys += [:account_number, :routing_number]

          # Filter these keys too, and log a hash of their values, so lines about the same value can
          # be found (default: email, email_address)
          config.filters.filter_keys_with_hashes += [:username]

          # Sensitive data in every string
          config.filters.credit_card_numbers = true  # Filter credit card numbers
          config.filters.email_addresses = true      # Filter email addresses
          config.filters.ip_addresses = false        # Filter IP addresses (off by default)
          config.filters.mac_addresses = false       # Filter MAC addresses (off by default)
          config.filters.phone_numbers = true        # Filter phone numbers
          config.filters.ssns = true                 # Filter social security numbers
          config.filters.url_passwords = true        # Filter passwords in URLs
          config.filters.url_query_params = true     # Filter sensitive params in URLs (?token=...)
          config.filters.authorization_credentials = true # Bearer tokens and Basic credentials in text

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
        refute LogStruct::ParamFilters.should_filter_key?("account_number_last4")
        assert LogStruct::ParamFilters.should_filter_key?("username")
        assert LogStruct::ParamFilters.should_include_string_hash?("username")
        assert LogStruct::ParamFilters.should_filter_key?("internal_note")
        assert LogStruct::ParamFilters.should_filter_key?("number", "1", path: ["params", "bank", "number"])
        assert_equal 16, filters.hash_length
      end

      def test_limits_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: limits_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # How much of each logged value is written (the defaults)
          config.limits.max_hash_keys = 100           # The rest are counted in _more_keys
          config.limits.max_array_items = 10          # Followed by "... and N more items"
          config.limits.max_backtrace_lines = 20      # Arrays that look like backtraces
          config.limits.max_string_bytes = 32_768     # Longer strings are cut, and say how long they were
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: limits_configuration
        # ----------------------------------------------------------

        # The example shows the defaults
        assert_equal LogStruct::ConfigStruct::Limits.new.serialize, LogStruct.config.limits.serialize
      end

      def test_error_handling_modes
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: error_handling_modes
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          modes = config.error_handling_modes

          # The defaults:
          # Sorbet type errors: raised in development and test, logged and reported in production
          modes.type_checking_errors = LogStruct::ErrorHandlingMode::ReportProduction
          # Errors inside LogStruct: raised in development and test, logged in production
          modes.logstruct_errors = LogStruct::ErrorHandlingMode::LogProduction
          # CSRF and IP spoofing errors: logged and reported (Rails still responds as usual)
          modes.security_errors = LogStruct::ErrorHandlingMode::Report
          # Errors LogStruct's integrations pass on, such as a mailer's delivery error: raised
          modes.standard_errors = LogStruct::ErrorHandlingMode::Raise
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: error_handling_modes
        # ----------------------------------------------------------

        # Verify error handling modes are applied
        assert_equal LogStruct::ErrorHandlingMode::ReportProduction,
          LogStruct.configuration.error_handling_modes.type_checking_errors
        assert_equal LogStruct::ErrorHandlingMode::LogProduction,
          LogStruct.configuration.error_handling_modes.logstruct_errors
        assert_equal LogStruct::ErrorHandlingMode::Report,
          LogStruct.configuration.error_handling_modes.security_errors
        assert_equal LogStruct::ErrorHandlingMode::Raise,
          LogStruct.configuration.error_handling_modes.standard_errors
      end
    end
  end
end
