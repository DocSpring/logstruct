# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "rails_structured_logging/version"
require "rails_structured_logging/logstop_fork"
require "rails_structured_logging/param_filters"
require "rails_structured_logging/log_formatter"
require "rails_structured_logging/configuration"
require "rails_structured_logging/host_authorization_response_app"
require "rails_structured_logging/rack"
require "rails_structured_logging/lograge"
require "rails_structured_logging/sidekiq"
require "rails_structured_logging/shrine"
require "rails_structured_logging/action_mailer"
require "rails_structured_logging/active_job"
require "rails_structured_logging/enums"
require "rails_structured_logging/log_types"
require "rails_structured_logging/railtie"

# Monkey-patch ActiveSupport::TaggedLogging::Formatter to support hash input/output
require "rails_structured_logging/monkey_patches/active_support/tagged_logging/formatter"

module RailsStructuredLogging
  extend T::Sig

  class Error < StandardError; end

  class << self
    extend T::Sig

    attr_accessor :configuration

    sig { params(block: T.nilable(T.proc.params(config: Configuration).void)).void }
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?

      # Configure Logstop email salt
      LogstopFork.email_salt = configuration.logstop_email_salt
    end

    sig { void }
    def initialize
      # Set up the Rails logger formatter
      ::Rails.logger.formatter = LogFormatter.new

      # Set up the integrations
      RailsStructuredLogging::Lograge.setup if configuration.lograge_enabled
      RailsStructuredLogging::ActionMailer.setup if configuration.actionmailer_integration_enabled
      RailsStructuredLogging::ActiveJob.setup if configuration.activejob_integration_enabled
      RailsStructuredLogging::HostAuthorizationResponseApp.setup if configuration.host_authorization_enabled
      if configuration.rack_middleware_enabled
        RailsStructuredLogging::Rack.setup(::Rails.application)
      end
      RailsStructuredLogging::Sidekiq.setup if configuration.sidekiq_integration_enabled
      RailsStructuredLogging::Shrine.setup if configuration.shrine_integration_enabled
    end

    sig { returns(T::Boolean) }
    def enabled?
      configuration&.enabled || false
    end
  end

  # Initialize with defaults
  configure
end
