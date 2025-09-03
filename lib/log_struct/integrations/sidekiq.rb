# typed: strict
# frozen_string_literal: true

begin
  require "sidekiq"
rescue LoadError
  # Sidekiq gem is not available, integration will be skipped
end
require_relative "sidekiq/logger" if defined?(::Sidekiq)

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
        end

        # Configure Sidekiq client (Rails app) to use our logger
        ::Sidekiq.configure_client do |sidekiq_config|
          sidekiq_config.logger = LogStruct::Integrations::Sidekiq::Logger.new("Sidekiq-Client")
        end

        true
      end
    end
  end
end
