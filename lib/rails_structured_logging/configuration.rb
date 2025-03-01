# frozen_string_literal: true

module RailsStructuredLogging
  # Configuration class for RailsStructuredLogging
  class Configuration
    attr_accessor :enabled, :lograge_enabled, :silence_noisy_loggers, :logstop_email_salt

    def initialize
      @enabled = nil # nil means use default logic
      @lograge_enabled = true
      @silence_noisy_loggers = true
      @logstop_email_salt = 'l0g5t0p'
    end
  end
end
