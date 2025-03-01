# typed: false
# frozen_string_literal: true

require 'sorbet-runtime'
require 'rails_structured_logging/version'
require 'rails_structured_logging/logstop_fork'
require 'rails_structured_logging/param_filters'
require 'rails_structured_logging/log_formatter'
require 'rails_structured_logging/configuration'
require 'rails_structured_logging/host_authorization_response_app'
require 'rails_structured_logging/rack'
require 'rails_structured_logging/lograge'
require 'rails_structured_logging/sidekiq'
require 'rails_structured_logging/shrine'
require 'rails_structured_logging/action_mailer'
require 'rails_structured_logging/active_job'
require 'rails_structured_logging/enums'
require 'rails_structured_logging/log_types'
require 'rails_structured_logging/railtie' if defined?(Rails)

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
begin
  require 'active_support/tagged_logging'
rescue LoadError
end
if defined?(ActiveSupport::TaggedLogging)
  require 'rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter'
end

module RailsStructuredLogging
  extend T::Sig

  class Error < StandardError; end

  class << self
    extend T::Sig

    attr_accessor :configuration

    sig { params(block: T.nilable(T.proc.params(config: Configuration).void)).void }
    def configure(&block)
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?

      # Configure Logstop email salt
      LogstopFork.email_salt = configuration.logstop_email_salt
    end

    sig { void }
    def setup_integrations
      # Set up the Rails logger formatter
      Rails.logger.formatter = LogFormatter.new if defined?(Rails) && Rails.logger

      # Set up the integrations
      Lograge.setup if configuration.lograge_enabled
      ActionMailer.setup if configuration.actionmailer_integration_enabled
      ActiveJob.setup if configuration.activejob_integration_enabled
      HostAuthorizationResponseApp.setup if configuration.host_authorization_enabled
      Rack.setup(Rails.application) if defined?(Rails) && configuration.rack_middleware_enabled
      Sidekiq.setup if configuration.sidekiq_integration_enabled
      Shrine.setup if configuration.shrine_integration_enabled
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration&.enabled || false
    end
  end

  # Initialize with defaults
  configure
end
