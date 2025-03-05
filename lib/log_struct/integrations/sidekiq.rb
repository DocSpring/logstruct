# typed: strict
# frozen_string_literal: true

begin
  require "sidekiq"
rescue LoadError
  # Sidekiq gem is not available, integration will be skipped
end
require_relative "sidekiq/logger" if defined?(::Sidekiq)
require_relative "../logger_utils"

module LogStruct
  module Integrations
    # Sidekiq integration for structured logging
    module Sidekiq
      extend T::Sig
      extend IntegrationInterface

      # Set up Sidekiq structured logging
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless defined?(::Sidekiq)
        return unless config.enabled
        return unless config.integrations.enable_sidekiq

        # Configure Sidekiq server (worker) to use our logger
        ::Sidekiq.configure_server do |sidekiq_config|
          sidekiq_config.logger = LogStruct::LoggerUtils.create_logger(
            LogStruct::Integrations::Sidekiq::Logger,
            original_logger: sidekiq_config.logger
          )
        end

        # Configure Sidekiq client (Rails app) to use our logger
        ::Sidekiq.configure_client do |sidekiq_config|
          sidekiq_config.logger = LogStruct::LoggerUtils.create_logger(
            LogStruct::Integrations::Sidekiq::Logger,
            original_logger: sidekiq_config.logger
          )
        end

        true
      end
    end
  end
end
