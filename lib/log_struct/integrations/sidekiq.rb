# typed: true
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
        # Set up Sidekiq structured logging
        def setup
          return unless defined?(::Sidekiq)
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_sidekiq

          # Configure Sidekiq server (worker) to use our formatter
          ::Sidekiq.configure_server do |config|
            config.logger = Integrations::Sidekiq::Logger.new
          end

          # Configure Sidekiq client (Rails app) to use our formatter
          ::Sidekiq.configure_client do |config|
            config.logger = Integrations::Sidekiq::Logger.new
          end
        end
      end
    end
  end
end
