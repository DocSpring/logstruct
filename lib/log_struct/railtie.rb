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
    # Configure early, right after logger initialization
    initializer "logstruct.configure_logger", after: :initialize_logger do |app|
      next unless LogStruct.enabled?

      # Use SemanticLogger for powerful logging features
      LogStruct::SemanticLogger::Setup.configure_semantic_logger(app)
    end

    # Setup all integrations after logger setup is complete
    initializer "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      # Merge Rails filter parameters into our filters
      LogStruct.merge_rails_filter_parameters!

      # Set up non-middleware integrations first
      Integrations.setup_integrations(stage: :non_middleware)

      # Note: Host allowances are managed by the test app itself.
    end

    # Setup middleware integrations during Rails configuration (before middleware stack is built)
    # Must be done in the Railtie class body, not in an initializer
    initializer "logstruct.configure_middleware", before: :build_middleware_stack do |app|
      # This runs before middleware stack is frozen, so we can configure it
      next unless LogStruct.enabled?

      Integrations.setup_integrations(stage: :middleware)
    end

    # Emit Puma lifecycle logs when running `rails server`
    initializer "logstruct.puma_lifecycle", after: "logstruct.configure_logger" do
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
        begin
          warn("[logstruct] puma lifecycle init")
        rescue
        end
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
