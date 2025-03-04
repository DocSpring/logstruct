# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RackErrorHandler
      # Custom middleware to enhance Rails error logging with JSON format and request details
      class Middleware
        extend T::Sig

        CONTENT_TYPE_HEADER = "Content-Type"
        CONTENT_TYPE_TEXT = "text/plain"
        IP_SPOOF_RESPONSE = "Forbidden: IP Spoofing Detected"
        CSRF_RESPONSE = "Forbidden: CSRF Error"

        sig { params(app: T.untyped).void }
        def initialize(app)
          @app = app
        end

        sig { params(env: T.untyped).returns(T.untyped) }
        def call(env)
          return @app.call(env) unless LogStruct.enabled?

          # Try to process the request
          begin
            @app.call(env)
          rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError => ip_spoof_error
            # Create a security log for IP spoofing
            security_log = Log::Security.new(
              event: LogEvent::IPSpoof,
              message: ip_spoof_error.message,
              # Can't call .remote_ip on the request because that's what raises the error.
              # Have to pass the client_ip and x_forwarded_for headers.
              client_ip: env["HTTP_CLIENT_IP"],
              x_forwarded_for: env["HTTP_X_FORWARDED_FOR"],
              path: env["PATH_INFO"],
              http_method: env["REQUEST_METHOD"],
              user_agent: env["HTTP_USER_AGENT"],
              referer: env["HTTP_REFERER"],
              request_id: env["action_dispatch.request_id"]
            )

            # Log the structured data
            ::Rails.logger.warn(security_log)

            # Report the error
            context = extract_request_context(env)
            LogStruct.handle_exception(ip_spoof_error, source: Source::Security, context: context)

            # If handle_exception raised an exception then Rails will deal with it (e.g. config.exceptions_app)
            # If we are only logging or reporting these security errors, then return a default response
            [403, {CONTENT_TYPE_HEADER => CONTENT_TYPE_TEXT}, [IP_SPOOF_RESPONSE]]
          rescue ::ActionController::InvalidAuthenticityToken => invalid_auth_token_error
            # Create a security log for CSRF error
            request = ::ActionDispatch::Request.new(env)
            security_log = Log::Security.new(
              event: LogEvent::CSRFViolation,
              message: invalid_auth_token_error.message,
              path: request.path,
              http_method: request.method,
              source_ip: request.remote_ip,
              user_agent: request.user_agent,
              referer: request.referer,
              request_id: request.request_id
            )
            LogStruct.log(security_log)

            # Report to error reporting service and/or re-raise
            context = extract_request_context(env)
            LogStruct.handle_exception(invalid_auth_token_error, source: Source::Security, context: context)

            # If handle_exception raised an exception then Rails will deal with it (e.g. config.exceptions_app)
            # If we are only logging or reporting these security errors, then return a default response
            [403, {CONTENT_TYPE_HEADER => CONTENT_TYPE_TEXT}, [CSRF_RESPONSE]]
          rescue => error
            # Extract request context for error reporting
            context = extract_request_context(env)
            
            # Create and log a structured exception with request context
            exception_log = Log::Exception.from_exception(
              Source::Request,
              error,
              context
            )
            LogStruct.log(exception_log)

            # Re-raise any standard errors to let Rails or error reporter handle it.
            # Rails will also log the request details separately
            raise error
          end
        end

        private

        sig { params(env: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
        def extract_request_context(env)
          request = ::ActionDispatch::Request.new(env)
          {
            request_id: request.request_id,
            path: request.path,
            method: request.method,
            user_agent: request.user_agent,
            referer: request.referer
          }
        rescue => error
          # If we can't extract request context, return minimal info
          {error_extracting_context: error.message}
        end

      end
    end
  end
end
