# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/show_exceptions"
require_relative "rack_error_handler/middleware"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module RackErrorHandler
      extend T::Sig
      extend IntegrationInterface

      # Set up Rack middleware for structured error logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless config.enabled
        return nil unless config.integrations.enable_rack_error_handler

        # Add structured logging middleware for security violations and errors
        # Need to insert before RemoteIp to catch IP spoofing errors it raises
        ::Rails.application.middleware.insert_before(
          ::ActionDispatch::RemoteIp,
          Integrations::RackErrorHandler::Middleware
        )

        true
      end
    end
  end
end
