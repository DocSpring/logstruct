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

    sig { returns(String) }
    attr_accessor :email_hashing_salt

    LogScrubberProcType = T.type_alias { T.nilable(T.proc.params(msg: String).returns(String)) }
    sig { returns(LogScrubberProcType) }
    attr_accessor :log_scrubber

    sig { returns(T.nilable(T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))) }
    attr_accessor :lograge_custom_options

    ErrorNotificationCallbackType = T.type_alias {
      T.proc.params(
        error: StandardError,
        recipients: T::Array[String],
        message: String
      ).void
    }
    sig { returns(ErrorNotificationCallbackType) }
    attr_accessor :email_error_notification_callback

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
      @email_hashing_salt = T.let("l0g5t0p", String)
      @log_scrubber = T.let(nil, LogScrubberProcType)

      # Applications can provide a proc to extend lograge options
      @lograge_custom_options = nil

      # Some email delivery issues should not be considered exceptions.
      # e.g. Postmark errors like inactive recipient, blocked address, invalid email address.
      # You can configure this callback to send Slack notifications instead of an error report to your bug tracker.
      # Default: Log to Rails.logger.info
      @email_error_notification_callback = T.let(lambda { |error, recipients, message|
        ::Rails.logger.info(
          "Email delivery error notification: #{error.class}: #{message} Recipients: #{recipients}"
        )
      },
        ErrorNotificationCallbackType)

      @actionmailer_integration_enabled = T.let(true, T::Boolean) # Enable ActionMailer integration by default
      @host_authorization_enabled = T.let(true, T::Boolean) # Enable host authorization logging by default
      @activejob_integration_enabled = T.let(true, T::Boolean) # Enable ActiveJob integration by default
      @rack_middleware_enabled = T.let(true, T::Boolean) # Enable Rack middleware for error logging by default
      @sidekiq_integration_enabled = T.let(true, T::Boolean) # Enable Sidekiq integration by default
      @shrine_integration_enabled = T.let(true, T::Boolean) # Enable Shrine integration by default
      @active_storage_integration_enabled = T.let(true, T::Boolean) # Enable ActiveStorage integration by default
      @carrierwave_integration_enabled = T.let(true, T::Boolean) # Enable CarrierWave integration by default

      # Data scrubbing options (we include a fork of Logstop in this gem)
      @filter_emails = T.let(true, T::Boolean) # Filter email addresses by default
      @filter_url_passwords = T.let(true, T::Boolean) # Filter passwords in URLs by default
      @filter_credit_cards = T.let(true, T::Boolean) # Filter credit card numbers by default
      @filter_phones = T.let(true, T::Boolean) # Filter phone numbers by default
      @filter_ssns = T.let(true, T::Boolean) # Filter social security numbers by default
      @filter_ips = T.let(false, T::Boolean) # Don't filter IP addresses by default
      @filter_macs = T.let(false, T::Boolean) # Don't filter MAC addresses by default
    end
  end
end
