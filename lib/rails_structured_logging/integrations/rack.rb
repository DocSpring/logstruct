# typed: true
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack/error_handling_middleware"

module RailsStructuredLogging
  module Integrations
    # Rack middleware integration for structured logging
    module Rack
      class << self
        # Set up Rack middleware for structured error logging
        def setup(app)
          return unless RailsStructuredLogging.enabled?
          return unless RailsStructuredLogging.configuration.rack_middleware_enabled

          # Add structured logging middleware for security violations and errors
          # Need to insert after ShowExceptions to catch IP spoofing errors
          app.middleware.insert_after(
            ::ActionDispatch::ShowExceptions,
            Integrations::Rack::ErrorHandlingMiddleware
          )
        end
      end
    end
  end
end
