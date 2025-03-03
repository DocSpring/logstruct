# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Rack
      # Custom middleware to enhance Rails error logging with JSON format and request details
      class ErrorHandlingMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          return @app.call(env) unless LogStruct.enabled?

          # Try to process the request
          begin
            @app.call(env)
          rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError => ip_spoof_error
            # Create a security log for IP spoofing
            security_log = LogStruct::Log::Security.new(
              sec_evt: LogSecurityEvent::IPSpoof,
              msg: ip_spoof_error.message,
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

            # Return a custom response for IP spoofing instead of raising
            [403, {"Content-Type" => "text/plain"}, ["Forbidden: IP Spoofing Detected"]]
          rescue ::ActionController::InvalidAuthenticityToken => invalid_auth_token_error
            # Create a security log for CSRF error
            request = ::ActionDispatch::Request.new(env)
            security_log = LogStruct::Log::Security.new(
              sec_evt: LogSecurityEvent::CSRFError,
              msg: invalid_auth_token_error.message,
              path: request.path,
              http_method: request.method,
              source_ip: request.remote_ip,
              user_agent: request.user_agent,
              referer: request.referer,
              request_id: request.request_id
            )

            # Log the structured data
            ::Rails.logger.warn(security_log)

            # Report to error reporting service and re-raise
            context = extract_request_context(env)
            MultiErrorReporter.report_exception(invalid_auth_token_error, context)
            raise # Re-raise to let Rails handle the response
          rescue => error
            # Log other exceptions with request context
            log_event(
              env,
              level: :error,
              event: LogEvent::RequestError,
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
            src: LogSource::Rails,
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
