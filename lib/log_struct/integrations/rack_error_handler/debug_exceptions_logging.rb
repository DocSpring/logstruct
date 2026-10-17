# typed: strict
# frozen_string_literal: true

require_relative "error_lines"

module LogStruct
  module Integrations
    module RackErrorHandler
      # Prepended to ActionDispatch::DebugExceptions. For an error the app didn't handle, Rails logs a
      # block of text (the error, its source code and its trace) before ShowExceptions renders the
      # error page. LogStruct writes an error line instead.
      module DebugExceptionsLogging
        extend T::Sig
        extend T::Helpers

        requires_ancestor { ::ActionDispatch::DebugExceptions }

        private

        sig { params(request: ::ActionDispatch::Request, wrapper: T.untyped).returns(T.untyped) }
        def log_error(request, wrapper)
          return super unless ErrorLines.enabled?
          # As Rails does: config.action_dispatch.log_rescued_responses = false leaves out the errors
          # Rails turns into a response of their own (404 for a routing error, 422 for CSRF)
          return if !request.get_header("action_dispatch.log_rescued_responses") && wrapper.rescue_response?

          ErrorLines.log_unhandled(request, wrapper)
        rescue => e
          LogStruct.handle_exception(e, source: Source::Internal, context: {integration: :rack_error_handler})
          super
        end
      end
    end
  end
end
