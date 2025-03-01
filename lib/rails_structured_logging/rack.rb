# frozen_string_literal: true

begin
  require 'rack'
rescue LoadError
  # Rack gem is not available, integration will be skipped
end

if defined?(Rack)
  require_relative 'rack/error_handling_middleware'
end

module RailsStructuredLogging
  # Rack middleware integration for structured logging
  module Rack
    class << self
      # Set up Rack middleware for structured error logging
      def setup(app)
        return unless defined?(::Rails) && defined?(ActionDispatch::ShowExceptions)
        return unless RailsStructuredLogging.enabled?
        return unless RailsStructuredLogging.configuration.rack_middleware_enabled

        # Add structured logging middleware for security violations and errors
        # Insert after ShowExceptions to catch IP spoofing errors
        app.middleware.insert_after ActionDispatch::ShowExceptions, RailsStructuredLogging::Rack::ErrorHandlingMiddleware
      end
    end
  end
end
