# frozen_string_literal: true

require_relative 'constants'

module RailsStructuredLogging
  # Configuration class for RailsStructuredLogging
  class Configuration
    attr_accessor :enabled, :lograge_enabled, :logstop_email_salt, :lograge_custom_options,
                  :actionmailer_integration_enabled, :host_authorization_enabled,
                  :activejob_integration_enabled, :rack_middleware_enabled,
                  :sidekiq_integration_enabled, :shrine_integration_enabled,
                  :filter_emails, :filter_url_passwords, :filter_credit_cards,
                  :filter_phones, :filter_ssns, :filter_ips, :filter_macs

    def initialize
      @enabled = nil # nil means use default logic
      @lograge_enabled = true
      @logstop_email_salt = 'l0g5t0p'
      @lograge_custom_options = nil # Applications can provide a proc to extend lograge options
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
