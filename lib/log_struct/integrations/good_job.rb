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

        compact_error_lines

        true
      end

      # GoodJob::LogSubscriber logs errors as text with the whole backtrace in the message (over 10KB).
      # GoodJob calls `on_thread_error` for every error its job and timer tasks raise, and the thread
      # error handler logs each one as a structured line, so finished_job_task and finished_timer_task
      # log nothing. The notifier only calls `on_thread_error` after repeated connection errors, so its
      # errors (and systemd's) are still logged, without the backtrace.
      module CompactErrorLines
        extend T::Sig
        extend T::Helpers

        requires_ancestor { ::GoodJob::LogSubscriber }

        sig { params(_event: T.untyped).void }
        def finished_timer_task(_event)
        end

        sig { params(_event: T.untyped).void }
        def finished_job_task(_event)
        end

        sig { params(event: T.untyped).void }
        def notifier_notify_error(event)
          exception = event.payload[:error]
          return unless exception

          error { "Notifier errored: #{exception.class}: #{exception}" }
        end

        sig { params(event: T.untyped).void }
        def systemd_watchdog_error(event)
          exception = event.payload[:error]
          return unless exception

          error { "Error pinging systemd: #{exception.class}: #{exception}" }
        end
      end

      # Logs each thread error as a structured line, then calls the handler the app set as
      # `on_thread_error` (GoodJob's README sets one to report errors to an error tracker). Every
      # GoodJob component passes its thread errors to `GoodJob._on_thread_error`, so this works
      # whenever the app sets its handler: GoodJob's engine applies config.good_job.on_thread_error
      # after LogStruct's setup.
      module LogThreadErrors
        extend T::Sig

        sig { params(exception: StandardError).void }
        def _on_thread_error(exception)
          LogStruct::Integrations::GoodJob.log_thread_error(exception)
          super
        end
      end

      # Configure GoodJob to use LogStruct's structured logger
      sig { void }
      def self.configure_logger
        return unless defined?(::GoodJob)

        # Not GoodJob, which here is this module
        goodjob_module = ::GoodJob

        # Replace GoodJob.logger with our structured logger if GoodJob is available
        if goodjob_module.respond_to?(:logger=)
          goodjob_module.logger = LogStruct::Integrations::GoodJob::Logger.new("GoodJob")

          # GoodJob's executable adds a plain text STDOUT logger unless GoodJob.logger already writes
          # to STDOUT, which it can't tell for this logger
          if defined?(::GoodJob::CLI) && ::GoodJob::CLI.respond_to?(:log_to_stdout=)
            ::GoodJob::CLI.log_to_stdout = false
          end
        end

        configure_thread_error_handler
      end

      sig { void }
      def self.configure_thread_error_handler
        return unless defined?(::GoodJob)

        # Not GoodJob, which here is this module
        goodjob_singleton = ::GoodJob.singleton_class
        return unless goodjob_singleton.method_defined?(:_on_thread_error)

        goodjob_singleton.prepend(LogThreadErrors) unless goodjob_singleton.ancestors.include?(LogThreadErrors)
      end

      sig { params(exception: StandardError).void }
      def self.log_thread_error(exception)
        ::GoodJob.logger.error(
          LogStruct::Log::GoodJob::Error.new(
            error_class: exception.class.name || exception.class.to_s,
            error_message: exception.message,
            backtrace: exception.backtrace,
            level: LogStruct::Level::Error,
            process_id: ::Process.pid,
            thread_id: Thread.current.object_id.to_s(36)
          )
        )
      end

      # Only when LogThreadErrors logs thread errors instead
      sig { void }
      def self.compact_error_lines
        return unless defined?(::GoodJob::LogSubscriber)
        return unless ::GoodJob.singleton_class.ancestors.include?(LogThreadErrors)

        log_subscriber = ::GoodJob::LogSubscriber
        log_subscriber.prepend(CompactErrorLines) unless log_subscriber.ancestors.include?(CompactErrorLines)
      end

      # Subscribe to GoodJob's ActiveSupport notifications
      sig { void }
      def self.subscribe_to_notifications
        return unless defined?(::GoodJob)

        # Subscribe to our custom log subscriber for GoodJob events
        LogStruct::Integrations::GoodJob::LogSubscriber.attach_to :good_job
      end

      private_class_method :configure_logger
      private_class_method :compact_error_lines
      private_class_method :configure_thread_error_handler
      private_class_method :subscribe_to_notifications
    end
  end
end
