# typed: strict
# frozen_string_literal: true

module LogStruct
  # Configuration class for LogStruct
  class Configuration
    module CustomHandlers
      StringScrubber = T.type_alias { T.nilable(T.proc.params(msg: String).returns(String)) }
      ExceptionReporter = T.type_alias {
        T.proc.params(
          error: StandardError,
          context: T::Hash[Symbol, T.untyped]
        ).void
      }
    end

    # -------------------------------------------------------------------------------------
    # Core Settings
    # -------------------------------------------------------------------------------------

    # Environments where LogStruct should be enabled automatically
    # Default: [:production]
    sig { returns(T::Array[Symbol]) }
    attr_accessor :environments

    # Enable or disable LogStruct manually
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :enabled

    # -------------------------------------------------------------------------------------
    # Error Handling
    # -------------------------------------------------------------------------------------

    # Environments where errors should be raised locally
    # Default: [:test, :development]
    sig { returns(T::Array[Symbol]) }
    attr_accessor :local_environments

    # How to handle different types of errors
    # Modes:
    # - :ignore - always ignore the error
    # - :log - always log the error
    # - :report - always report to tracking service and continue
    # - :log_production - log in production, raise locally
    # - :report_production - report in production, raise locally
    # - :raise - always raise regardless of environment
    #
    # Default: {
    #   type_errors: :log_production,     # Sorbet type errors - raise in test/dev, log in prod
    #   logstruct_errors: :raise,         # Our own errors - always raise
    #   other_errors: :log               # Everything else - just log
    # }
    sig { returns(T::Hash[Symbol, ErrorHandlingMode]) }
    attr_accessor :error_handling

    # Enable or disable Lograge integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :lograge_enabled

    # Custom options for Lograge
    # Default: nil
    sig { returns(T.nilable(T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))) }
    attr_accessor :lograge_custom_options

    # Custom handler for exception reporting
    # Default: nil
    sig { returns(CustomHandlers::ExceptionReporter) }
    attr_accessor :exception_reporting_handler

    # Enable or disable ActionMailer integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :actionmailer_integration_enabled

    # Enable or disable host authorization logging
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :host_authorization_enabled

    # Enable or disable ActiveJob integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :activejob_integration_enabled

    # Enable or disable Rack middleware
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :rack_middleware_enabled

    # Enable or disable Sidekiq integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :sidekiq_integration_enabled

    # Enable or disable Shrine integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :shrine_integration_enabled

    # Enable or disable ActiveStorage integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :active_storage_integration_enabled

    # Enable or disable CarrierWave integration
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :carrierwave_integration_enabled

    # -------------------------------------------------------------------------------------
    # Param filtering options
    # -------------------------------------------------------------------------------------

    # Keys that should be filtered in nested structures such as request params and job arguments.
    # Filtered data includes information about Hashes and Arrays.
    #
    # { _filtered: {
    #     _class: "Hash",                # Class of the filtered value
    #     _bytes: 1234,                  # Length of JSON string in bytes
    #     _keys_count: 3,                # Number of keys in the hash
    #     _keys: [:key1, :key2, :key3],  # First 10 keys in the hash
    #   }
    # }
    #
    # Default: [:password, :password_confirmation, :pass, :pw, :token, :secret,
    #           :credentials, :creds, :auth, :authentication, :authorization]
    #
    sig { returns(T::Array[Symbol]) }
    attr_reader :filtered_keys

    sig { params(value: T.untyped).returns(T::Array[Symbol]) }
    def filtered_keys=(value)
      @filtered_keys = Array(value).map { |v| v.to_s.downcase.to_sym }.freeze
    end

    # Keys where string values should include an SHA256 hash.
    # Useful for tracing emails across requests (e.g. sign in, sign up) while protecting privacy.
    # Default: [:email, :email_address]
    sig { returns(T::Array[Symbol]) }
    attr_reader :filtered_keys_with_string_hash

    sig { params(value: T.untyped).returns(T::Array[Symbol]) }
    def filtered_keys_with_string_hash=(value)
      @filtered_keys_with_string_hash = Array(value).map { |v| v.to_s.downcase.to_sym }.freeze
    end

    # Hash salt for SHA256 hashing (typically used for email addresses)
    # Used for both param filters and string scrubbing
    # Default: "l0g5t0p"
    sig { returns(String) }
    attr_accessor :hash_salt

    # Hash length for SHA256 hashing (typically used for email addresses)
    # Used for both param filters and string scrubbing
    # Default: 12
    sig { returns(Integer) }
    attr_accessor :hash_length

    # -------------------------------------------------------------------------------------
    # Filtering options for all strings, including plain logs, error messages, etc.
    # -------------------------------------------------------------------------------------

    # Filter email addresses. Also controls email filtering for the ActionMailer integration
    # (to, from, recipient fields, etc.)
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :filter_emails

    # Filter URL passwords
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :filter_url_passwords

    # Filter credit card numbers
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :filter_credit_cards

    # Filter phone numbers
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :filter_phones

    # Filter social security numbers
    # Default: true
    sig { returns(T::Boolean) }
    attr_accessor :filter_ssns

    # Filter IP addresses
    # Default: false
    sig { returns(T::Boolean) }
    attr_accessor :filter_ips

    # Filter MAC addresses
    # Default: false
    sig { returns(T::Boolean) }
    attr_accessor :filter_macs

    # Custom log scrubbing handler for any additional string scrubbing
    # Default: nil
    sig { returns(CustomHandlers::StringScrubber) }
    attr_accessor :string_scrubbing_handler

    sig { void }
    def initialize
      @enabled = T.let(true, T::Boolean)
      @lograge_enabled = T.let(true, T::Boolean)

      # Core configuration

      # Which environments should have JSON logs?
      # Default: [:test, :production]
      @environments = T.let([:test, :production], T::Array[Symbol])

      # Error handling configuration
      # Which environments should be considered local? (e.g. for :log_production)
      @local_environments = T.let([:test, :development], T::Array[Symbol])

      # Error handling configuration
      @error_handling = T.let(
        {
          # Sorbet type errors
          # Default: Raise in test/dev, log in production
          # Feel free to change this to :ignore if you don't care about type errors.
          type_errors: ErrorHandlingMode::LogProduction.serialize,
          # Internal LogStruct errors
          # Default: Raise in test/dev, log in prod
          # These are any errors that may occur during log filtering and formatting.
          # (If you raise these in production you won't see any logs for the crashed requests.)
          logstruct_errors: ErrorHandlingMode::LogProduction.serialize,
          # All other errors (StandardError)
          # Default: Always re-raise errors after logging
          standard_errors: ErrorHandlingMode::Raise.serialize
        },
        T::Hash[Symbol, Symbol]
      )

      # Applications can provide a proc to extend lograge options
      @lograge_custom_options = nil

      # This is used in a few cases where it makes sense to report an exception
      # while allowing the code to continue without crashing. This is especially important for
      # logging-related errors where we need to print valid JSON even if something goes wrong.
      # e.g. a crash or infinite loop while filtering and scrubbing log data.
      @exception_reporting_handler = T.let(lambda { |error, context|
        exception_data = LogStruct::Log::Exception.from_exception(
          LogStruct::LogSource::App,
          LogStruct::LogEvent::Error,
          error,
          context
        )
        # Log using the structured format
        ::Rails.logger.error(exception_data)
      },
        CustomHandlers::ExceptionReporter)

      @actionmailer_integration_enabled = T.let(true, T::Boolean) # Enable ActionMailer integration by default
      @host_authorization_enabled = T.let(true, T::Boolean) # Enable host authorization logging by default
      @activejob_integration_enabled = T.let(true, T::Boolean) # Enable ActiveJob integration by default
      @rack_middleware_enabled = T.let(true, T::Boolean) # Enable Rack middleware for error logging by default
      @sidekiq_integration_enabled = T.let(true, T::Boolean) # Enable Sidekiq integration by default
      @shrine_integration_enabled = T.let(true, T::Boolean) # Enable Shrine integration by default
      @active_storage_integration_enabled = T.let(true, T::Boolean) # Enable ActiveStorage integration by default
      @carrierwave_integration_enabled = T.let(true, T::Boolean) # Enable CarrierWave integration by default

      # Param filtering configuration - Keys that should be filtered in
      # nested structures such as request params and job arguments.
      # Examples:
      #
      # { _filtered: {
      #     _class: "Hash",                # Class of the filtered value
      #     _bytes: 1234,                  # Length of JSON string in bytes
      #     _keys_count: 3,                # Number of keys in the hash
      #     _keys: [:key1, :key2, :key3],  # First 10 keys in the hash
      #   }
      # }
      #
      # { _filtered: {
      #     _class: "Array",               # Class of the filtered value
      #     _count: 3,                     # Number of items in the array
      #     _bytes: 1234,                  # Length of JSON string in bytes
      #   }
      # }
      #
      # { _filtered: {
      #     _class: "String",              # Class of the filtered value
      #     _bytes: 12,                    # Length of the string in bytes
      #     _hash: "abcd1234567890"        # Short SHA256 hash, opt-in only for specific keys (e.g. emails)
      #   }
      # }
      @filtered_keys = T.let(%i[
        password password_confirmation pass pw token secret
        credentials auth authentication authorization
        credit_card ssn social_security
      ].freeze,
        T::Array[Symbol])

      # Keys that should be hashed rather than completely filtered
      # By default, we hash email and email_address fields
      @filtered_keys_with_string_hash = T.let(%i[
        email email_address
      ].freeze,
        T::Array[Symbol])

      # Log scrubbing options
      # (The StringScrubber class is a vendored fork of https://github.com/ankane/logstop)
      @string_scrubbing_handler = T.let(nil, CustomHandlers::StringScrubber)
      @filter_emails = T.let(true, T::Boolean) # Filter email addresses by default
      @hash_salt = T.let("l0g5t0p", String)
      @hash_length = T.let(12, Integer)
      @filter_url_passwords = T.let(true, T::Boolean) # Filter passwords in URLs by default
      @filter_credit_cards = T.let(true, T::Boolean) # Filter credit card numbers by default
      @filter_phones = T.let(true, T::Boolean) # Filter phone numbers by default
      @filter_ssns = T.let(true, T::Boolean) # Filter social security numbers by default
      @filter_ips = T.let(false, T::Boolean) # Don't filter IP addresses by default
      @filter_macs = T.let(false, T::Boolean) # Don't filter MAC addresses by default
    end

    # Check if errors should be raised in the current environment
    sig { returns(T::Boolean) }
    def should_raise?
      local_environments.include?(::Rails.env.to_sym)
    end

    # Check if LogStruct should be enabled in the current environment
    sig { returns(T::Boolean) }
    def enabled_for_environment?
      enabled && environments.include?(::Rails.env.to_sym)
    end
  end
end
