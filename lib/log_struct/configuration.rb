# typed: strict
# frozen_string_literal: true

module LogStruct
  # Configuration class for LogStruct
  class Configuration
    # Define typed attributes
    sig { returns(T::Boolean) }
    attr_accessor :enabled

    sig { returns(T::Boolean) }
    attr_accessor :lograge_enabled

    sig { returns(T.nilable(T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))) }
    attr_accessor :lograge_custom_options
    # New configuration options for exception reporting and notifications

    ExceptionReportingHandler = T.type_alias {
      T.proc.params(
        error: StandardError,
        context: T::Hash[Symbol, T.untyped]
      ).void
    }
    sig { returns(ExceptionReportingHandler) }
    attr_accessor :exception_reporting_handler

    # Integration flags
    sig { returns(T::Boolean) }
    attr_accessor :actionmailer_integration_enabled

    sig { returns(T::Boolean) }
    attr_accessor :host_authorization_enabled

    sig { returns(T::Boolean) }
    attr_accessor :activejob_integration_enabled

    sig { returns(T::Boolean) }
    attr_accessor :rack_middleware_enabled

    sig { returns(T::Boolean) }
    attr_accessor :sidekiq_integration_enabled

    sig { returns(T::Boolean) }
    attr_accessor :shrine_integration_enabled

    sig { returns(T::Boolean) }
    attr_accessor :active_storage_integration_enabled

    sig { returns(T::Boolean) }
    attr_accessor :carrierwave_integration_enabled

    sig { returns(String) }
    attr_accessor :email_hash_salt

    sig { returns(Integer) }
    attr_accessor :email_hash_length

    LogScrubbingHandler = T.type_alias { T.nilable(T.proc.params(msg: String).returns(String)) }
    sig { returns(LogScrubbingHandler) }
    attr_accessor :log_scrubbing_handler

    # Filtering options
    sig { returns(T::Boolean) }
    attr_accessor :filter_emails

    sig { returns(T::Boolean) }
    attr_accessor :filter_url_passwords

    sig { returns(T::Boolean) }
    attr_accessor :filter_credit_cards

    sig { returns(T::Boolean) }
    attr_accessor :filter_phones

    sig { returns(T::Boolean) }
    attr_accessor :filter_ssns

    sig { returns(T::Boolean) }
    attr_accessor :filter_ips

    sig { returns(T::Boolean) }
    attr_accessor :filter_macs

    sig { void }
    def initialize
      @enabled = T.let(true, T::Boolean)
      @lograge_enabled = T.let(true, T::Boolean)

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
        ExceptionReportingHandler)

      @actionmailer_integration_enabled = T.let(true, T::Boolean) # Enable ActionMailer integration by default
      @host_authorization_enabled = T.let(true, T::Boolean) # Enable host authorization logging by default
      @activejob_integration_enabled = T.let(true, T::Boolean) # Enable ActiveJob integration by default
      @rack_middleware_enabled = T.let(true, T::Boolean) # Enable Rack middleware for error logging by default
      @sidekiq_integration_enabled = T.let(true, T::Boolean) # Enable Sidekiq integration by default
      @shrine_integration_enabled = T.let(true, T::Boolean) # Enable Shrine integration by default
      @active_storage_integration_enabled = T.let(true, T::Boolean) # Enable ActiveStorage integration by default
      @carrierwave_integration_enabled = T.let(true, T::Boolean) # Enable CarrierWave integration by default

      # Log scrubbing options
      # (The LogScrubber class is a vendored fork of https://github.com/ankane/logstop)
      @log_scrubbing_handler = T.let(nil, LogScrubbingHandler)
      @filter_emails = T.let(true, T::Boolean) # Filter email addresses by default
      @email_hash_salt = T.let("l0g5t0p", String)
      @email_hash_length = T.let(12, Integer)
      @filter_url_passwords = T.let(true, T::Boolean) # Filter passwords in URLs by default
      @filter_credit_cards = T.let(true, T::Boolean) # Filter credit card numbers by default
      @filter_phones = T.let(true, T::Boolean) # Filter phone numbers by default
      @filter_ssns = T.let(true, T::Boolean) # Filter social security numbers by default
      @filter_ips = T.let(false, T::Boolean) # Don't filter IP addresses by default
      @filter_macs = T.let(false, T::Boolean) # Don't filter MAC addresses by default
    end
  end
end
