# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "enums"

module RailsStructuredLogging
  # Configuration class for RailsStructuredLogging
  class Configuration
    extend T::Sig

    # Define typed attributes
    sig { returns(T.nilable(T::Boolean)) }
    attr_accessor :enabled

    sig { params(value: T.nilable(T::Boolean)).void }
    sig { returns(T::Boolean) }
    attr_accessor :lograge_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(String) }
    attr_accessor :logstop_email_salt

    sig { params(value: String).void }
    sig { returns(T.nilable(T.proc.params(event: T.untyped, options: T.untyped).returns(T.untyped))) }
    attr_accessor :lograge_custom_options

    # Notification callback for email delivery errors
    sig { params(value: T.nilable(T.proc.params(event: T.untyped, options: T.untyped).returns(T.untyped))).void }
    sig { returns(T.nilable(T.proc.params(error: StandardError, recipients: String, message: String).void)) }
    attr_accessor :email_error_notification_callback

    # Integration flags
    sig { params(value: T.nilable(T.proc.params(error: StandardError, recipients: String, message: String).void)).void }
    sig { returns(T::Boolean) }
    attr_accessor :actionmailer_integration_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :host_authorization_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :activejob_integration_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :rack_middleware_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :sidekiq_integration_enabled

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :shrine_integration_enabled

    # Filtering options
    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_emails

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_url_passwords

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_credit_cards

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_phones

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_ssns

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_ips

    sig { params(value: T::Boolean).void }
    sig { returns(T::Boolean) }
    attr_accessor :filter_macs

    sig { params(value: T::Boolean).void }
    sig { void }
    def initialize
      @enabled = nil # nil means use default logic
      @lograge_enabled = true
      @logstop_email_salt = "l0g5t0p"
      @lograge_custom_options = nil # Applications can provide a proc to extend lograge options

      # Some email delivery issues should not be considered exceptions.
      # e.g. Postmark errors like inactive recipient, blocked address, invalid email address.
      # You can configure this callback to send Slack notifications instead of an error report to your bug tracker.
      # Default: Log to Rails.logger.info
      @email_error_notification_callback = lambda { |error, recipients, message|
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
