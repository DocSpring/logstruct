# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack/error_handling_middleware"
require_relative "rack_setup"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module Rack
      extend T::Sig
      extend IntegrationInterface

      # Set up Rack middleware for structured error logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless RackSetup.enabled?(config)

        # Add structured logging middleware for security violations and errors
        # Need to insert after ShowExceptions to catch IP spoofing errors
        RackSetup.insert_after(
          ::ActionDispatch::ShowExceptions,
          Integrations::RackErrorHandler::Middleware
        )
        true
      end
    end
  end
end
