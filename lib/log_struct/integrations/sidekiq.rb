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

      @original_logger = T.let(nil, T.untyped)

      # Set up Sidekiq structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::Sidekiq)
        return nil unless config.enabled
        return nil unless config.integrations.enable_sidekiq

        configure_logger

        ::Sidekiq.configure_server do |sidekiq_config|
          # First in the chain, so lines logged by other middleware include the job too
          sidekiq_config.server_middleware do |chain|
            chain.prepend LogStruct::Integrations::Sidekiq::JobContextMiddleware
          end

          replace_default_error_handler(sidekiq_config)
        end

        true
      end

      # Use LogStruct's logger for Sidekiq's own lines. The Railtie calls this as soon as it replaces
      # Rails.logger, before config/initializers run, because an initializer that configures Sidekiq
      # (connecting to Redis, setting up a fetcher) logs with Sidekiq's logger straight away.
      sig { void }
      def self.configure_logger
        return unless defined?(::Sidekiq)

        current = sidekiq_logger_config.logger
        return if current.is_a?(LogStruct::Integrations::Sidekiq::Logger)

        @original_logger = current
        name = ::Sidekiq.server? ? "Sidekiq-Server" : "Sidekiq-Client"
        sidekiq_logger_config.logger = LogStruct::Integrations::Sidekiq::Logger.new(name)
      end

      # Put Sidekiq's own logger back, when an initializer turned LogStruct or this integration off
      # after configure_logger ran
      sig { void }
      def self.restore_logger
        return unless defined?(::Sidekiq)
        return if @original_logger.nil?

        sidekiq_logger_config.logger = @original_logger
        @original_logger = nil
      end

      # Sidekiq 7 keeps the logger on its default configuration, Sidekiq 6 on the module
      sig { returns(T.untyped) }
      def self.sidekiq_logger_config
        ::Sidekiq.respond_to?(:default_configuration) ? ::Sidekiq.default_configuration : ::Sidekiq
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

      # The line has the job's ID and class in ctx, like the lines logged while the job ran (Sidekiq
      # calls its error handlers after the job's middleware has finished).
      sig { params(error: Exception, context: T::Hash[T.untyped, T.untyped]).void }
      def self.log_job_error(error, context)
        job = context[:job]
        job = nil unless job.is_a?(Hash)

        # LogStruct's ActiveJob integration already logs the errors of ActiveJob jobs
        return if job&.key?("wrapped") && LogStruct.config.integrations.enable_activejob
        error_context = context[:context]

        line = Log::Sidekiq::Error.new(
          error_class: error.class,
          message: error.message,
          backtrace: error.backtrace,
          error_context: error_context&.to_s,
          queue_name: job&.dig("queue")&.to_s,
          retry_count: job&.dig("retry_count")
        )
        if job.nil?
          ::Rails.logger.warn(line)
          return
        end

        job_context = {
          jid: job["jid"],
          class: job["display_class"] || job["wrapped"] || job["class"]
        }.compact
        ::SemanticLogger.named_tagged(sidekiq_context: job_context) { ::Rails.logger.warn(line) }
      end

      JOB_ERROR_HANDLER = T.let(
        ->(error, context, _config = nil) { log_job_error(error, context) },
        T.proc.params(error: Exception, context: T::Hash[T.untyped, T.untyped], config: T.untyped).void
      )

      private_class_method :sidekiq_logger_config, :replace_default_error_handler, :log_job_error
    end
  end
end
