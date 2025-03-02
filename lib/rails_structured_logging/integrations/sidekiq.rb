# typed: true
# frozen_string_literal: true

begin
  require "sidekiq"
rescue LoadError
  # Sidekiq gem is not available, integration will be skipped
end
require_relative "sidekiq/formatter" if defined?(::Sidekiq)

module RailsStructuredLogging
  module Integrations
    # Sidekiq integration for structured logging
    module Sidekiq
      class << self
        # Set up Sidekiq structured logging
        def setup
          return unless defined?(::Sidekiq)
          return unless RailsStructuredLogging.enabled?
          return unless RailsStructuredLogging.configuration.sidekiq_integration_enabled

          # Configure Sidekiq server (worker) to use our formatter
          ::Sidekiq.configure_server do |config|
            config.logger.formatter = Formatter.new
          end

          # Configure Sidekiq client (Rails app) to use our formatter
          ::Sidekiq.configure_client do |config|
            config.logger.formatter = Formatter.new
          end
        end
      end
    end
  end
end
