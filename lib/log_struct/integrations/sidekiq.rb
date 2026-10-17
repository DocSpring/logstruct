# typed: strict
# frozen_string_literal: true

begin
  require "sidekiq"
rescue LoadError
  # Sidekiq gem is not available, integration will be skipped
end
if defined?(::Sidekiq)
  require_relative "sidekiq/logger"
  require_relative "sidekiq/job_context_middleware"
end

module LogStruct
  module Integrations
    # Sidekiq integration for structured logging
    module Sidekiq
      extend T::Sig
      extend IntegrationInterface

      # Set up Sidekiq structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::Sidekiq)
        return nil unless config.enabled
        return nil unless config.integrations.enable_sidekiq

        # Configure Sidekiq server (worker) to use our logger
        ::Sidekiq.configure_server do |sidekiq_config|
          sidekiq_config.logger = LogStruct::Integrations::Sidekiq::Logger.new("Sidekiq-Server")

          # First in the chain, so lines logged by other middleware include the job too
          sidekiq_config.server_middleware do |chain|
            chain.prepend LogStruct::Integrations::Sidekiq::JobContextMiddleware
          end

          replace_default_error_handler(sidekiq_config)
        end

        # Configure Sidekiq client (Rails app) to use our logger
        ::Sidekiq.configure_client do |sidekiq_config|
          sidekiq_config.logger = LogStruct::Integrations::Sidekiq::Logger.new("Sidekiq-Client")
        end

        true
      end

      # Sidekiq's default error handler logs three lines for each failed job: the job (with its
      # arguments) as a JSON string, the error, and the backtrace. Log one structured line instead,
      # without the arguments, which LogStruct can't filter inside a JSON string.
      sig { params(sidekiq_config: T.untyped).void }
      def self.replace_default_error_handler(sidekiq_config)
        return unless defined?(::Sidekiq::Config::ERROR_HANDLER)

        handlers = sidekiq_config.error_handlers
        return unless handlers.delete(::Sidekiq::Config::ERROR_HANDLER)

        handlers.unshift(JOB_ERROR_HANDLER)
      end

      sig { params(error: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def self.log_job_error(error, context)
        job = context[:job]
        job = nil unless job.is_a?(Hash)

        # LogStruct's ActiveJob integration already logs the errors of ActiveJob jobs
        return if job&.key?("wrapped") && LogStruct.config.integrations.enable_activejob

        details = {
          context: context[:context],
          jid: job&.dig("jid"),
          job_class: job && (job["wrapped"] || job["class"]),
          queue: job&.dig("queue"),
          retry_count: job&.dig("retry_count")
        }.compact

        if error.is_a?(StandardError)
          ::Rails.logger.warn(Log.from_exception(Source::Sidekiq, error, details))
        else
          # Log::Error only takes a StandardError; Sidekiq also reports others (e.g. NoMemoryError)
          ::Rails.logger.warn(Log::Sidekiq.new(
            level: Level::Warn,
            event: Event::Error,
            message: "#{error.class.name}: #{error.message}",
            context: details
          ))
        end
      end

      JOB_ERROR_HANDLER = T.let(
        ->(error, context, _config = nil) { log_job_error(error, context) },
        T.proc.params(error: Exception, context: T::Hash[T.untyped, T.untyped], config: T.untyped).void
      )

      private_class_method :replace_default_error_handler, :log_job_error
    end
  end
end
