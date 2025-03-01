# frozen_string_literal: true

begin
  require 'active_job'
rescue LoadError
  # ActiveJob gem is not available, integration will be skipped
end

if defined?(ActiveJob)
  require_relative 'active_job/structured_log_subscriber'
end

module RailsStructuredLogging
  # ActiveJob integration for structured logging
  module ActiveJob
    class << self
      # Set up ActiveJob structured logging
      def setup
        return unless defined?(::ActiveJob)
        return unless RailsStructuredLogging.enabled?
        return unless RailsStructuredLogging.configuration.activejob_integration_enabled

        # Detach the default text formatter
        ::ActiveJob::LogSubscriber.detach_from :active_job

        # Attach our structured formatter
        RailsStructuredLogging::ActiveJob::StructuredLogSubscriber.attach_to :active_job
      end
    end
  end
end
