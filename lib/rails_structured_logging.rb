# frozen_string_literal: true

require 'rails_structured_logging/version'
require 'rails_structured_logging/configuration'
require 'rails_structured_logging/logstop'
require 'rails_structured_logging/param_filters'
require 'rails_structured_logging/log_formatter'
require 'rails_structured_logging/lograge'
require 'rails_structured_logging/railtie' if defined?(Rails)

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash inputs if needed
require 'rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter' if defined?(ActiveSupport::TaggedLogging)

module RailsStructuredLogging
  class Error < StandardError; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?

      # Apply configuration settings
      Logstop.email_salt = configuration.logstop_email_salt
    end

    def setup
      return unless enabled?

      # Set up the formatter for Rails.logger
      if defined?(Rails) && Rails.logger
        Rails.logger.formatter = LogFormatter.new
      end

      # Configure lograge if available and enabled
      Lograge.setup if configuration.lograge_enabled
    end

    def enabled?
      return configuration.enabled if configuration.enabled != nil
      return true if defined?(Rails) && Rails.env.production?
      return true if ENV['STRUCTURED_LOGGING'] == 'true'
      false
    end
  end

  # Initialize with default configuration
  configure
end
