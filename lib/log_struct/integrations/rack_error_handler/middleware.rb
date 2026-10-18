# typed: strict
# frozen_string_literal: true

require_relative "../rack_middleware"
require_relative "error_lines"

module LogStruct
  module Integrations
    module RackErrorHandler
      # Logs the errors that get past ShowExceptions, or come from the middleware outside it (an IP
      # spoofing error from a middleware that reads remote_ip, for example), then raises them again
      # for the server to handle as it would without LogStruct
      class Middleware < RackMiddleware
        sig { override.params(env: T.untyped).returns(T.untyped) }
        def call(env)
          @app.call(env)
        rescue => error
          begin
            ErrorLines.log_escaped(::ActionDispatch::Request.new(env), error)
          rescue => logging_error
            LogStruct.handle_exception(logging_error, source: Source::Internal)
          end
          raise error
        end
      end
    end
  end
end
