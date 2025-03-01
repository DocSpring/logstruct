# frozen_string_literal: true

begin
  require 'shrine'
rescue LoadError
  # Shrine gem is not available, integration will be skipped
end

module RailsStructuredLogging
  # Shrine integration for structured logging
  module Shrine
    class << self
      # Set up Shrine structured logging
      def setup
        return unless defined?(::Shrine)
        return unless RailsStructuredLogging.enabled?
        return unless RailsStructuredLogging.configuration.shrine_integration_enabled

        # Create a structured log subscriber for Shrine
        shrine_log_subscriber = lambda do |event|
          payload = event.payload.except(:io, :metadata, :name).dup
          payload[:src] = 'shrine'
          payload[:evt] = event.name
          payload[:duration] = event.duration

          # Handle record references safely
          if payload.dig(:options, :record).present?
            payload[:options][:record_id] = payload[:options][:record].id
            payload[:options][:record_class] = payload[:options][:record].class.name
            payload[:options].delete(:record)
          end

          # Pass the structured hash to the logger
          # If Rails.logger has our LogFormatter, it will handle JSON conversion
          host_authorization_enabled          ::Shrine.logger.info payload
        end

        # Configure Shrine to use our structured log subscriber
        ::Shrine.plugin :instrumentation,
                      log_events: [:upload, :exists, :download, :delete],
                      log_subscriber: shrine_log_subscriber
      end
    end
  end
end
