# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack/error_handling_middleware"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module Rack
      class << self
        extend T::Sig
        # Set up Rack middleware for structured error logging
        sig { params(app: T.untyped).void }
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
