# frozen_string_literal: true

require 'rails_structured_logging/version'
require 'rails_structured_logging/logstop_fork'
require 'rails_structured_logging/param_filters'
require 'rails_structured_logging/log_formatter'
require 'rails_structured_logging/configuration'
require 'rails_structured_logging/railtie' if defined?(Rails)
require 'rails_structured_logging/host_authorization'
require 'rails_structured_logging/rack'
require 'rails_structured_logging/lograge'
require 'rails_structured_logging/sidekiq'
require 'rails_structured_logging/shrine'
require 'rails_structured_logging/action_mailer'
require 'rails_structured_logging/active_job'

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash inputs if needed
require 'rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter' if defined?(ActiveSupport::TaggedLogging)

module RailsStructuredLogging
  class Error < StandardError; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?

      # Configure Logstop email salt
      LogstopFork.email_salt = configuration.logstop_email_salt

      # Set up the integrations
      setup_integrations if configuration.enabled
    end

    def setup_integrations
      # Set up the Rails logger formatter
      Rails.logger.formatter = LogFormatter.new

      # Set up the integrations
      Lograge.setup if configuration.lograge_enabled
      ActionMailer.setup if configuration.actionmailer_integration_enabled
      ActiveJob.setup if configuration.activejob_integration_enabled
      HostAuthorization.setup if configuration.host_authorization_enabled
      Rack.setup(Rails.application) if configuration.rack_middleware_enabled
      Sidekiq.setup if configuration.sidekiq_integration_enabled
      Shrine.setup if configuration.shrine_integration_enabled

      # Silence noisy loggers if enabled
      silence_noisy_loggers if configuration.silence_noisy_loggers
    end

    def silence_noisy_loggers
      return unless defined?(Rails) && Rails.respond_to?(:logger)

      Rails.application.config.after_initialize do
        dev_null_logger = Logger.new('/dev/null')

        # Silence Ahoy
        Ahoy.logger = dev_null_logger if defined?(Ahoy)

        # Silence ActiveModelSerializers
        ActiveModelSerializers.logger = dev_null_logger if defined?(ActiveModelSerializers)

        # Silence default ActionMailer logs (we use our own structured logging)
        ActionMailer::Base.logger = dev_null_logger if defined?(ActionMailer::Base)
      end
    end

    def enabled?
      configuration&.enabled
    end
  end

  # Initialize with defaults
  configure
end
