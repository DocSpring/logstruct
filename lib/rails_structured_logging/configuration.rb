# frozen_string_literal: true

module RailsStructuredLogging
  # Configuration class for RailsStructuredLogging
  class Configuration
    attr_accessor :enabled, :lograge_enabled, :silence_noisy_loggers, :logstop_email_salt, :lograge_custom_options, :actionmailer_integration_enabled, :host_authorization_enabled, :activejob_integration_enabled, :rack_middleware_enabled, :sidekiq_integration_enabled, :shrine_integration_enabled

    def initialize
      @enabled = nil # nil means use default logic
      @lograge_enabled = true
      @silence_noisy_loggers = true
      @logstop_email_salt = 'l0g5t0p'
      @lograge_custom_options = nil # Applications can provide a proc to extend lograge options
      @actionmailer_integration_enabled = true # Enable ActionMailer integration by default
      @host_authorization_enabled = true # Enable host authorization logging by default
      @activejob_integration_enabled = true # Enable ActiveJob integration by default
      @rack_middleware_enabled = true # Enable Rack middleware for error logging by default
      @sidekiq_integration_enabled = true # Enable Sidekiq integration by default
      @shrine_integration_enabled = true # Enable Shrine integration by default
    end
  end
end
