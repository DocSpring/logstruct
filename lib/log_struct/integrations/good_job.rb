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

        # GoodJob applies config.good_job in an after_initialize block, so an app that sets
        # `on_thread_error` there (as GoodJob's README does) replaces the handler set above
        if defined?(::Rails) && ::Rails.application && !::Rails.application.initialized?
          ::Rails.application.config.after_initialize { configure_thread_error_handler }
        end

        # Subscribe to GoodJob's ActiveSupport notifications
        subscribe_to_notifications

        silence_thread_error_lines

        true
      end

      # GoodJob calls `on_thread_error` for every error its job and timer tasks raise, then sends the
      # finished_job_task and finished_timer_task notifications. GoodJob::LogSubscriber logs those as
      # "GoodJob error: ..." text with the whole backtrace in the message (over 10KB). The thread error
      # handler already logs each error as a structured line, so these methods log nothing.
      module SilenceThreadErrorLines
        extend T::Sig

        sig { params(_event: T.untyped).void }
        def finished_timer_task(_event)
        end

        sig { params(_event: T.untyped).void }
        def finished_job_task(_event)
        end
      end

      @thread_error_handler = T.let(nil, T.nilable(T.proc.params(exception: StandardError).void))

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

      # Log thread errors, after calling the handler the app set (GoodJob's README sets one
      # to report them to an error tracker). Setting up again keeps the one handler.
      sig { void }
      def self.configure_thread_error_handler
        return unless defined?(::GoodJob)

        # Not GoodJob, which here is this module
        goodjob_module = ::GoodJob

        if goodjob_module.respond_to?(:on_thread_error=)
          app_handler = goodjob_module.on_thread_error
          return if app_handler&.equal?(@thread_error_handler)

          @thread_error_handler = ->(exception) do
            app_handler&.call(exception)
            log_entry = LogStruct::Log::GoodJob::Error.new(
              error_class: exception.class.name,
              error_message: exception.message,
              backtrace: exception.backtrace,
              level: LogStruct::Level::Error,
              process_id: ::Process.pid,
              thread_id: Thread.current.object_id.to_s(36)
            )
            goodjob_module.logger.error(log_entry)
          end
          goodjob_module.on_thread_error = @thread_error_handler
        end
      end

      # Only when the thread error handler logs these errors instead
      sig { void }
      def self.silence_thread_error_lines
        return unless defined?(::GoodJob::LogSubscriber)
        return unless ::GoodJob.respond_to?(:on_thread_error=)

        log_subscriber = ::GoodJob::LogSubscriber
        log_subscriber.prepend(SilenceThreadErrorLines) unless log_subscriber.ancestors.include?(SilenceThreadErrorLines)
      end

      # Subscribe to GoodJob's ActiveSupport notifications
      sig { void }
      def self.subscribe_to_notifications
        return unless defined?(::GoodJob)

        # Subscribe to our custom log subscriber for GoodJob events
        LogStruct::Integrations::GoodJob::LogSubscriber.attach_to :good_job
      end

      private_class_method :configure_logger
      private_class_method :silence_thread_error_lines
      private_class_method :configure_thread_error_handler
      private_class_method :subscribe_to_notifications
    end
  end
end
