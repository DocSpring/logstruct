# typed: true
# frozen_string_literal: true

module RailsStructuredLogging
  module Integrations
    module Rack
      # Custom middleware to enhance Rails error logging with JSON format and request details
      class ErrorHandlingMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          return @app.call(env) unless RailsStructuredLogging.enabled?

          # Try to process the request
          begin
            @app.call(env)
          rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError => ip_spoof_error
            log_event(
              env,
              event: Enums::EventType::SecurityViolation.serialize,
              level: :warn,
              violation_type: Enums::ViolationType::IpSpoof.serialize,
              error: ip_spoof_error.message,
              # Can't call .remote_ip on the request because that's what raises the error.
              # Have to pass the client_ip and x_forwarded_for headers.
              client_ip: env["HTTP_CLIENT_IP"],
              x_forwarded_for: env["HTTP_X_FORWARDED_FOR"]
            )

            # Return a custom response for IP spoofing instead of raising
            [403, {"Content-Type" => "text/plain"}, ["Forbidden: IP Spoofing Detected"]]
          rescue ::ActionController::InvalidAuthenticityToken => invalid_auth_token_error
            # Handle CSRF token errors
            log_event(
              env,
              level: :warn,
              event: Enums::EventType::SecurityViolation.serialize,
              violation_type: Enums::ViolationType::Csrf.serialize,
              error: invalid_auth_token_error.message
            )

            # Report to error reporting service and re-raise
            context = extract_request_context(env)
            MultiErrorReporter.report_exception(invalid_auth_token_error, context)
            raise # Re-raise to let Rails handle the response
          rescue => error
            # Log other exceptions with request context
            log_event(
              env,
              level: :error,
              event: Enums::EventType::RequestError.serialize,
              error_class: error.class.to_s,
              error_message: error.message
            )

            # Report to error reporting service and re-raise
            context = extract_request_context(env)
            MultiErrorReporter.report_exception(error, context)
            raise # Re-raise to let Rails handle the response
          end
        end

        private

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

        def log_event(env, event:, level:, client_ip: nil, **custom_fields)
          # WARNING: Calling .remote_ip on the request will raise an error
          # if this is a remote IP spoofing attack. It's still safe to call
          # any other methods.
          request = ::ActionDispatch::Request.new(env)

          log_data = {
            src: Enums::SourceType::Rails.serialize,
            evt: event,
            level: level,
            request_id: request.request_id,
            client_ip: client_ip || request.remote_ip,
            path: request.path,
            method: request.method,
            user_agent: request.user_agent,
            referer: request.referer,
            **custom_fields
          }
          # We send a hash to the Rails log formatter which scrubs sensitive data,
          # adds tags, and then serializes it as JSON.
          ::Rails.logger.public_send(level, log_data)
        end
      end
    end
  end
end
