# frozen_string_literal: true

module RailsStructuredLogging
  # Lograge integration for structured request logging
  module Lograge
    class << self
      # Set up lograge for structured request logging
      def setup
        return unless defined?(Rails) && defined?(::Lograge)

        Rails.application.configure do
          config.lograge.enabled = true
          # Use a raw formatter that just returns the hash, which will then be formatted by our LogFormatter
          config.lograge.formatter = ->(data) { data }

          # Add custom options to lograge
          config.lograge.custom_options = lambda do |event|
            options = {}
            options[:src] = 'rails'
            options[:evt] = 'request'

            # Extract params if available
            begin
              options[:params] = event.payload[:params].except('controller', 'action') if event.payload[:params]
            rescue StandardError
              # Ignore errors in params extraction
            end

            # Add request_id if available
            options[:request_id] = event.payload[:request_id] if event.payload[:request_id]

            options
          end
        end
      end
    end
  end
end
