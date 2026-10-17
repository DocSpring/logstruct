# typed: strict
# frozen_string_literal: true

require "rack"
require "action_dispatch/middleware/debug_exceptions"
require_relative "rack_error_handler/middleware"
require_relative "rack_error_handler/debug_exceptions_logging"
require_relative "rack_setup"

module LogStruct
  module Integrations
    # Rack middleware integration for structured logging
    module RackErrorHandler
      extend T::Sig
      extend IntegrationInterface

      @interceptor_registered = T.let(false, T::Boolean)

      # Set up structured lines for CSRF and IP spoofing errors, errors the app didn't handle, and
      # errors that get past ShowExceptions
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless RackSetup.enabled?(config)

        # Errors from the middleware outside ShowExceptions, and any that get past it
        RackSetup.insert_before(
          ::ActionDispatch::RemoteIp,
          Integrations::RackErrorHandler::Middleware
        )
        # DebugExceptions calls its interceptors with each error from the app (in every environment),
        # before ShowExceptions turns it into Rails' usual response: 422 for a CSRF error
        unless @interceptor_registered
          ::ActionDispatch::DebugExceptions.register_interceptor(ErrorLines.method(:intercept))
          @interceptor_registered = true
        end
        # An error line instead of the text Rails logs for an error the app didn't handle
        unless ::ActionDispatch::DebugExceptions <= DebugExceptionsLogging
          ::ActionDispatch::DebugExceptions.prepend(DebugExceptionsLogging)
        end

        true
      end
    end
  end
end
