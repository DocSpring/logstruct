# typed: true
# frozen_string_literal: true

begin
  require "active_job"
  require "active_job/log_subscriber"
rescue LoadError
  # ActiveJob gem is not available, integration will be skipped
end

require_relative "active_job/structured_log_subscriber" if defined?(::ActiveJob::LogSubscriber)

module RailsStructuredLogging
  module Integrations
    # ActiveJob integration for structured logging
    module ActiveJob
      class << self
        # Set up ActiveJob structured logging
        def setup
          return unless defined?(::ActiveJob::LogSubscriber)
          return unless RailsStructuredLogging.enabled?
          return unless RailsStructuredLogging.configuration.activejob_integration_enabled

          ::ActiveSupport.on_load(:active_job) do
            # Detach the default text formatter
            ::ActiveJob::LogSubscriber.detach_from :active_job

            # Attach our structured formatter
            RailsStructuredLogging::ActiveJob::StructuredLogSubscriber.attach_to :active_job
          end
        end
      end
    end
  end
end
