# typed: true
# frozen_string_literal: true

begin
  require "shrine"
rescue LoadError
  # Shrine gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # Shrine integration for structured logging
    module Shrine
      class << self
        # Set up Shrine structured logging
        sig { void }
        def setup
          return unless defined?(::Shrine)
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.shrine_integration_enabled

          # Create a structured log subscriber for Shrine
          # ActiveSupport::Notifications::Event has name, time, end, transaction_id, payload, and duration
          shrine_log_subscriber = T.unsafe(lambda do |event|
            payload = event.payload.except(:io, :metadata, :name).dup

            # Create structured log data
            log_data = Log::Shrine.new(
              src: LogSource::Shrine,
              evt: LogEvent::FileOperation,
              duration: event.duration,
              operation: event.name,
              payload: payload
            )

            # Pass the structured hash to the logger
            # If Rails.logger has our JSONFormatter, it will handle JSON conversion
            ::Shrine.logger.info log_data
          end)

          # Configure Shrine to use our structured log subscriber
          ::Shrine.plugin :instrumentation,
            log_events: %i[upload exists download delete],
            log_subscriber: shrine_log_subscriber
        end
      end
    end
  end
end
