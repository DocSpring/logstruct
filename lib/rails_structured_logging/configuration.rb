# typed: false
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'enums'

module RailsStructuredLogging
  # Configuration class for RailsStructuredLogging
  class Configuration
    extend T::Sig

    # Define typed attributes
    sig { returns(T.nilable(T::Boolean)) }
    attr_reader :enabled

    sig { params(value: T.nilable(T::Boolean)).void }
    def enabled=(value)
      @enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :lograge_enabled

    sig { params(value: T::Boolean).void }
    def lograge_enabled=(value)
      @lograge_enabled = value
    end

    sig { returns(String) }
    attr_reader :logstop_email_salt

    sig { params(value: String).void }
    def logstop_email_salt=(value)
      @logstop_email_salt = value
    end

    sig { returns(T.nilable(T.proc.params(event: T.untyped, options: T.untyped).returns(T.untyped))) }
    attr_reader :lograge_custom_options

    sig { params(value: T.nilable(T.proc.params(event: T.untyped, options: T.untyped).returns(T.untyped))).void }
    def lograge_custom_options=(value)
      @lograge_custom_options = value
    end

    # Notification callback for email delivery errors
    sig { returns(T.nilable(T.proc.params(error: StandardError, recipients: String, message: String).void)) }
    attr_reader :email_error_notification_callback

    sig { params(value: T.nilable(T.proc.params(error: StandardError, recipients: String, message: String).void)).void }
    def email_error_notification_callback=(value)
      @email_error_notification_callback = value
    end

    # Integration flags
    sig { returns(T::Boolean) }
    attr_reader :actionmailer_integration_enabled

    sig { params(value: T::Boolean).void }
    def actionmailer_integration_enabled=(value)
      @actionmailer_integration_enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :host_authorization_enabled

    sig { params(value: T::Boolean).void }
    def host_authorization_enabled=(value)
      @host_authorization_enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :activejob_integration_enabled

    sig { params(value: T::Boolean).void }
    def activejob_integration_enabled=(value)
      @activejob_integration_enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :rack_middleware_enabled

    sig { params(value: T::Boolean).void }
    def rack_middleware_enabled=(value)
      @rack_middleware_enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :sidekiq_integration_enabled

    sig { params(value: T::Boolean).void }
    def sidekiq_integration_enabled=(value)
      @sidekiq_integration_enabled = value
    end

    sig { returns(T::Boolean) }
    attr_reader :shrine_integration_enabled

    sig { params(value: T::Boolean).void }
    def shrine_integration_enabled=(value)
      @shrine_integration_enabled = value
    end

    # Filtering options
    sig { returns(T::Boolean) }
    attr_reader :filter_emails

    sig { params(value: T::Boolean).void }
    def filter_emails=(value)
      @filter_emails = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_url_passwords

    sig { params(value: T::Boolean).void }
    def filter_url_passwords=(value)
      @filter_url_passwords = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_credit_cards

    sig { params(value: T::Boolean).void }
    def filter_credit_cards=(value)
      @filter_credit_cards = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_phones

    sig { params(value: T::Boolean).void }
    def filter_phones=(value)
      @filter_phones = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_ssns

    sig { params(value: T::Boolean).void }
    def filter_ssns=(value)
      @filter_ssns = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_ips

    sig { params(value: T::Boolean).void }
    def filter_ips=(value)
      @filter_ips = value
    end

    sig { returns(T::Boolean) }
    attr_reader :filter_macs

    sig { params(value: T::Boolean).void }
    def filter_macs=(value)
      @filter_macs = value
    end

    sig { void }
    def initialize
      @enabled = nil # nil means use default logic
      @lograge_enabled = true
      @logstop_email_salt = 'l0g5t0p'
      @lograge_custom_options = nil # Applications can provide a proc to extend lograge options

      # Some email delivery issues should not be considered exceptions.
      # e.g. Postmark errors like inactive recipient, blocked address, invalid email address.
      # You can configure this callback to send Slack notifications instead of an error report to your bug tracker.
      # Default: Log to Rails.logger.info
      @email_error_notification_callback = ->(error, recipients, message) {
        ::Rails.logger.info("Email delivery error notification: #{error.class}: #{message} Recipients: #{recipients}")
      }

      @actionmailer_integration_enabled = true # Enable ActionMailer integration by default
      @host_authorization_enabled = true # Enable host authorization logging by default
      @activejob_integration_enabled = true # Enable ActiveJob integration by default
      @rack_middleware_enabled = true # Enable Rack middleware for error logging by default
      @sidekiq_integration_enabled = true # Enable Sidekiq integration by default
      @shrine_integration_enabled = true # Enable Shrine integration by default

      # LogstopFork filtering options
      @filter_emails = true # Filter email addresses by default for security/compliance
      @filter_url_passwords = true # Filter passwords in URLs by default
      @filter_credit_cards = true # Filter credit card numbers by default
      @filter_phones = true # Filter phone numbers by default
      @filter_ssns = true # Filter social security numbers by default
      @filter_ips = false # Don't filter IP addresses by default
      @filter_macs = false # Don't filter MAC addresses by default
    end
  end
end
