# typed: true
# frozen_string_literal: true

begin
  require "lograge"
rescue LoadError
  # Lograge gem is not available, integration will be skipped
end

module RailsStructuredLogging
  # Lograge integration for structured request logging
  module Lograge
    class << self
      # Set up lograge for structured request logging
      def setup
        return unless defined?(::Lograge)

        ::Rails.application.configure do
          config.lograge.enabled = true
          # Use a raw formatter that just returns the hash, which will then be formatted by our LogFormatter
          config.lograge.formatter = ->(data) { data }

          # Add custom options to lograge
          config.lograge.custom_options = lambda do |event|
            # Extract essential fields from the payload
            options = event.payload.slice(
              :request_id,
              :host,
              :source_ip
            ).compact

            # Add standard metadata
            options[:src] = "rails"
            options[:evt] = "request"

            # Extract params if available
            options[:params] = event.payload[:params].except("controller", "action") if event.payload[:params].present?

            # Process headers if available
            process_headers(event, options)

            # Apply custom options from application if provided
            apply_custom_options(event, options)

            options
          end
        end
      end

      private

      # Process headers from the event payload
      def process_headers(event, options)
        headers = event.payload[:headers]
        return unless headers.present?

        options[:user_agent] = headers["HTTP_USER_AGENT"]
        options[:content_type] = headers["CONTENT_TYPE"]
        options[:accept] = headers["HTTP_ACCEPT"]

        options[:basic_auth] = true if headers["basic_auth"]
        return unless options[:basic_auth]

        # Include API token information for debugging authentication
        options[:basic_auth_username] = headers["basic_auth.username"]
        options[:basic_auth_password] = headers["basic_auth.password"]
      end

      # Apply custom options from the application's configuration
      def apply_custom_options(event, options)
        custom_options_proc = RailsStructuredLogging.configuration.lograge_custom_options
        return unless custom_options_proc.respond_to?(:call)

        # Call the proc with the event and options
        # The proc can modify the options hash directly
        custom_options_proc.call(event, options)
      end
    end
  end
end
