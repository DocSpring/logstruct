# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack_error_handler/middleware"
require_relative "rack_setup"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module RackErrorHandler
      extend T::Sig
      extend IntegrationInterface

      # Set up Rack middleware for structured error logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless RackSetup.enabled?(config)

        # Add structured logging middleware for security violations and errors
        # Need to insert before RemoteIp to catch IP spoofing errors it raises
        RackSetup.insert_before(
          ::ActionDispatch::RemoteIp,
          Integrations::RackErrorHandler::Middleware
        )

        true
      end
    end
  end
end
