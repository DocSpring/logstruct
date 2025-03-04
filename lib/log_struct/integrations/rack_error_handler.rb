# typed: true
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack_error_handler/middleware"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module RackErrorHandler
      class << self
        # Set up Rack middleware for structured error logging
        def setup(app)
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_rack_error_handler

          # Add structured logging middleware for security violations and errors
          # Need to insert after ShowExceptions to catch IP spoofing errors
          app.middleware.insert_after(
            ::ActionDispatch::ShowExceptions,
            Integrations::RackErrorHandler::Middleware
          )
        end
      end
    end
  end
end
