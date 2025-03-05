# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack/error_handling_middleware"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module Rack
      extend T::Sig
      extend IntegrationInterface

      # Set up Rack middleware for structured error logging
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless config.enabled
        return unless config.integrations.enable_rack_error_handler

        # Add structured logging middleware for security violations and errors
        # Need to insert after ShowExceptions to catch IP spoofing errors
        ::Rails.application.middleware.insert_after(
          ::ActionDispatch::ShowExceptions,
          Integrations::RackErrorHandler::Middleware
        )
      end
    end
  end
end
