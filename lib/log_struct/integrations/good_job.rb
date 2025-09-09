# typed: strict
# frozen_string_literal: true

begin
  require "good_job"
rescue LoadError
  # GoodJob gem is not available, integration will be skipped
end

require_relative "good_job/logger" if defined?(::GoodJob)
require_relative "good_job/log_subscriber" if defined?(::GoodJob)

module LogStruct
  module Integrations
    # GoodJob integration for structured logging
    #
    # GoodJob is a PostgreSQL-based ActiveJob backend that provides reliable,
    # scalable job processing for Rails applications. This integration provides
    # structured logging for all GoodJob operations.
    #
    # ## Features:
    # - Structured logging for job execution lifecycle
    # - Error tracking and retry logging
    # - Performance metrics and timing data
    # - Database operation logging
    # - Thread and process tracking
    # - Custom GoodJob logger with LogStruct formatting
    #
    # ## Integration Points:
    # - Replaces GoodJob.logger with LogStruct-compatible logger
    # - Subscribes to GoodJob's ActiveSupport notifications
    # - Captures job execution events, errors, and performance metrics
    # - Logs database operations and connection information
    #
    # ## Configuration:
    # The integration is automatically enabled when GoodJob is detected and
    # LogStruct configuration allows it. It can be disabled by setting:
    #
    # ```ruby
    # config.integrations.enable_goodjob = false
    # ```
    module GoodJob
      extend T::Sig
      extend IntegrationInterface

      # Set up GoodJob structured logging
      #
      # This method configures GoodJob to use LogStruct's structured logging
      # by replacing the default logger and subscribing to job events.
      #
      # @param config [LogStruct::Configuration] The LogStruct configuration
      # @return [Boolean, nil] Returns true if setup was successful, nil if skipped
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::GoodJob)
        return nil unless config.enabled
        return nil unless config.integrations.enable_goodjob

        # Replace GoodJob's logger with our structured logger
        configure_logger

        # Subscribe to GoodJob's ActiveSupport notifications
        subscribe_to_notifications

        true
      end

      # Configure GoodJob to use LogStruct's structured logger
      sig { void }
      def self.configure_logger
        return unless defined?(::GoodJob)

        # Use direct reference to avoid const_get - GoodJob is guaranteed to be defined here
        goodjob_module = T.unsafe(GoodJob)

        # Replace GoodJob.logger with our structured logger if GoodJob is available
        if goodjob_module.respond_to?(:logger=)
          goodjob_module.logger = LogStruct::Integrations::GoodJob::Logger.new("GoodJob")
        end

        # Configure error handling for thread errors if GoodJob supports it
        if goodjob_module.respond_to?(:on_thread_error=)
          goodjob_module.on_thread_error = ->(exception) do
            log_entry = LogStruct::Log::GoodJob::Error.new(
              err_class: exception.class.name,
              error_message: exception.message,
              backtrace: exception.backtrace,
              process_id: ::Process.pid,
              thread_id: Thread.current.object_id.to_s(36)
            )
            goodjob_module.logger.error(log_entry)
          end
        end
      end

      # Subscribe to GoodJob's ActiveSupport notifications
      sig { void }
      def self.subscribe_to_notifications
        return unless defined?(::GoodJob)

        # Subscribe to our custom log subscriber for GoodJob events
        LogStruct::Integrations::GoodJob::LogSubscriber.attach_to :good_job
      end

      private_class_method :configure_logger
      private_class_method :subscribe_to_notifications
    end
  end
end
