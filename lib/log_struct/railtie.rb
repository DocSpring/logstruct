# typed: strict
# frozen_string_literal: true

require "rails"
require "semantic_logger"
require_relative "formatter"
require_relative "semantic_logger/setup"
require_relative "integrations"

module LogStruct
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    # Replace the logger as soon as Rails creates it, so boot-time logs and anything that keeps
    # a reference to Rails.logger use LogStruct's logger
    initializer "logstruct.configure_logger", after: :initialize_logger do |app|
      next unless LogStruct.enabled?

      # Use SemanticLogger for powerful logging features
      LogStruct::SemanticLogger::Setup.configure_semantic_logger(app)

      # Initializers that configure Sidekiq log with its logger while config/initializers run
      Integrations::Sidekiq.configure_logger if LogStruct.config.integrations.enable_sidekiq
    end

    # Set up integrations after config/initializers, so that the settings in
    # config/initializers/logstruct.rb and filter_parameters added by other initializers apply
    initializer "logstruct.setup", after: :load_config_initializers, before: :build_middleware_stack do |app|
      # An initializer may have changed `enabled` or `enabled_environments` after the logger was
      # (or wasn't) replaced
      LogStruct.apply_initializer_settings!
      if LogStruct.enabled?
        if LogStruct::SemanticLogger::Setup.configured?
          # The formatter, colors, noisy logger filter and log file settings in config/initializers apply too
          LogStruct::SemanticLogger::Setup.reconfigure_appenders(app)
        else
          LogStruct::SemanticLogger::Setup.configure_semantic_logger(app)
        end
      elsif LogStruct::SemanticLogger::Setup.configured?
        LogStruct::SemanticLogger::Setup.restore_rails_logger(app)
      end
      unless LogStruct.enabled? && LogStruct.config.integrations.enable_sidekiq
        Integrations::Sidekiq.restore_logger
      end

      next unless LogStruct.enabled?

      # Merge Rails filter parameters into our filters
      LogStruct.merge_rails_filter_parameters!

      Integrations.setup_integrations(stage: :non_middleware)
    end

    # Add middleware before the middleware stack is built
    initializer "logstruct.configure_middleware", after: "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      Integrations.setup_integrations(stage: :middleware)
    end

    # Emit Puma lifecycle logs when running `rails server`
    initializer "logstruct.puma_lifecycle", after: "logstruct.configure_logger" do
      next unless LogStruct.enabled?
      is_server = ::LogStruct.server_mode?
      next unless is_server
      begin
        require "log_struct/log/puma"
        port = LogStruct::Integrations::Puma.port_from_argv(ARGV)
        started = LogStruct::Log::Puma::Start.new(
          mode: "single",
          environment: (defined?(::Rails) && ::Rails.respond_to?(:env)) ? ::Rails.env : nil,
          process_id: Process.pid,
          listening_addresses: port ? ["tcp://127.0.0.1:#{port}"] : nil
        )
        LogStruct.info(started)

        at_exit do
          shutdown = LogStruct::Log::Puma::Shutdown.new(
            process_id: Process.pid
          )
          LogStruct.info(shutdown)
        end
      rescue
        # best-effort
      end
    end

    # Delegate integration initializers to Integrations module
    LogStruct::Integrations.setup_initializers(self)
  end
end
