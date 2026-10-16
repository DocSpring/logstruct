# typed: strict
# frozen_string_literal: true

begin
  require "good_job"
rescue LoadError
  # GoodJob gem is not available, integration will be skipped
end

require_relative "good_job/logger" if defined?(::GoodJob)

module LogStruct
  module Integrations
    # GoodJob integration for structured logging
    #
    # GoodJob is a PostgreSQL-based ActiveJob backend. Its jobs are logged by the ActiveJob
    # integration (enqueued, started, finished, failed), so this integration covers GoodJob itself:
    #
    # - Replaces GoodJob.logger with a LogStruct logger, so GoodJob's own messages are JSON lines
    # - Logs each thread error as a structured error line, then calls the app's `on_thread_error`
    # - Stops GoodJob's own log subscriber logging those errors again with the whole backtrace
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
      # This method replaces GoodJob's logger and logs its thread errors as structured lines.
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

        compact_error_lines

        true
      end

      # GoodJob::LogSubscriber logs errors as text with the whole backtrace in the message (over 10KB).
      # GoodJob passes every error its job tasks raise, every systemd watchdog error and every notifier
      # error except connection errors to `on_thread_error`, which LogThreadErrors logs as a structured
      # line, so GoodJob's own lines for those are off. The notifier passes connection errors on only
      # once they repeat, so its line for them is kept, without the backtrace.
      module CompactErrorLines
        extend T::Sig
        extend T::Helpers

        requires_ancestor { ::GoodJob::LogSubscriber }

        sig { params(_event: T.untyped).void }
        def finished_job_task(_event)
        end

        sig { params(event: T.untyped).void }
        def notifier_notify_error(event)
          exception = event.payload[:error]
          return unless exception
          return unless LogStruct::Integrations::GoodJob.notifier_connection_error?(exception)

          error { "Notifier errored: #{exception.class}: #{exception}" }
        end

        sig { params(_event: T.untyped).void }
        def systemd_watchdog_error(_event)
        end
      end

      # Logs each thread error as a structured line, then calls the handler the app set as
      # `on_thread_error` (GoodJob's README sets one to report errors to an error tracker). Every
      # GoodJob component passes its thread errors to `GoodJob._on_thread_error`, so this works
      # whenever the app sets its handler: GoodJob's engine applies config.good_job.on_thread_error
      # after LogStruct's setup. GoodJob passes any Exception its handled_exceptions setting lets
      # through, not only StandardErrors.
      module LogThreadErrors
        extend T::Sig

        sig { params(exception: Exception).void }
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

      # A failed job's exception was already logged by the ActiveJob integration, with the job's
      # ID and class, so it isn't logged again here
      sig { params(exception: Exception).void }
      def self.log_thread_error(exception)
        return if LogStruct::LoggedErrors.logged?(exception)

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

      # The errors GoodJob's notifier holds back until they repeat (GoodJob::Notifier::CONNECTION_ERRORS)
      sig { params(exception: Exception).returns(T::Boolean) }
      def self.notifier_connection_error?(exception)
        return true unless defined?(::GoodJob::Notifier::CONNECTION_ERRORS)

        ::GoodJob::Notifier::CONNECTION_ERRORS.any? do |error_name|
          error_class = error_name.safe_constantize
          error_class.is_a?(Class) && exception.is_a?(error_class)
        end
      end

      # Only when LogThreadErrors logs thread errors instead
      sig { void }
      def self.compact_error_lines
        return unless defined?(::GoodJob::LogSubscriber)
        return unless ::GoodJob.singleton_class.ancestors.include?(LogThreadErrors)

        log_subscriber = ::GoodJob::LogSubscriber
        log_subscriber.prepend(CompactErrorLines) unless log_subscriber.ancestors.include?(CompactErrorLines)
      end

      private_class_method :configure_logger
      private_class_method :compact_error_lines
      private_class_method :configure_thread_error_handler
    end
  end
end
