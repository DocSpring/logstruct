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
      class << self
        extend T::Sig

        # Set up Sidekiq structured logging
        sig { returns(T.nilable(TrueClass)) }
        def setup
          return unless defined?(::Sidekiq)
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_sidekiq

          # Configure Sidekiq server (worker) to use our logger
          ::Sidekiq.configure_server do |config|
            config.logger = LogStruct::Integrations::Sidekiq::Logger.new(
              config.logger.instance_variable_get(:@logdev)&.dev || $stdout
            )
          end

          # Configure Sidekiq client (Rails app) to use our logger
          ::Sidekiq.configure_client do |config|
            config.logger = LogStruct::Integrations::Sidekiq::Logger.new(
              config.logger.instance_variable_get(:@logdev)&.dev || $stdout
            )
          end

          true
        end
      end
    end
  end
end
