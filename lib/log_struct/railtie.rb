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
    # Ensure test hosts are allowed early enough for middleware build
    initializer "logstruct.allow_test_hosts", before: :build_middleware_stack do |app|
      if ::Rails.env.test? && app.config.respond_to?(:hosts)
        begin
          app.config.hosts << /.*\z/
        rescue
          # best-effort
        end
        begin
          app.config.middleware.delete(::ActionDispatch::HostAuthorization)
        rescue
          # best-effort
        end
      end
    end

    # After ActionDispatch is configured, remove HostAuthorization in test to prevent 403s
    # (No late deletion needed; handled above before middleware stack is built)

    # Configure early, right after logger initialization
    initializer "logstruct.configure_logger", after: :initialize_logger do |app|
      next unless LogStruct.enabled?

      # Apply TaggedLogging monkey patch only when enabled
      require_relative "monkey_patches/active_support/tagged_logging/formatter"

      # Use SemanticLogger for powerful logging features
      LogStruct::SemanticLogger::Setup.configure_semantic_logger(app)
    end

    # Setup all integrations after logger setup is complete
    initializer "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      # Merge Rails filter parameters into our filters
      LogStruct.merge_rails_filter_parameters!

      # Set up all integrations
      Integrations.setup_integrations

      # Note: Host allowances are managed by the test app itself.
    end

    # Emit Puma lifecycle logs when running `rails server`
    initializer "logstruct.puma_lifecycle", after: "logstruct.configure_logger" do
      begin
        is_server = ::LogStruct.instance_variable_defined?(:@server_mode) && ::LogStruct.instance_variable_get(:@server_mode)
      rescue
        is_server = false
      end
      next unless is_server
      begin
        require "log_struct/log/puma"
        port = T.let(nil, T.nilable(String))
        ARGV.each_with_index do |arg, idx|
          if arg == "-p" || arg == "--port"
            port = ARGV[idx + 1]
            break
          elsif arg.start_with?("--port=")
            port = arg.split("=", 2)[1]
            break
          end
        end
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
