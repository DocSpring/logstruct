# frozen_string_literal: true

module RailsStructuredLogging
  module Rack
    # Custom middleware to enhance Rails error logging with JSON format and request details
    class HashLoggingErrorHandler
      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless RailsStructuredLogging.enabled?

        # Try to process the request
        begin
          @app.call(env)
        rescue ActionDispatch::RemoteIp::IpSpoofAttackError => e
          log_event(
            env,
            event: 'security_violation',
            level: :warn,
            violation_type: 'ip_spoof_attack',
            error: e.message,
            # Can't call .remote_ip on the request because that's what raises the error.
            # Have to pass the client_ip and x_forwarded_for headers.
            client_ip: env['HTTP_CLIENT_IP'],
            x_forwarded_for: env['HTTP_X_FORWARDED_FOR']
          )

          # Return a custom response for IP spoofing instead of raising
          [403, { 'Content-Type' => 'text/plain' }, ['Forbidden: IP Spoofing Detected']]
        rescue ActionController::InvalidAuthenticityToken => e
          # Handle CSRF token errors
          log_event(
            env,
            level: :warn,
            event: 'security_violation',
            violation_type: 'csrf_token_error',
            error: e.message
          )
          raise # Re-raise to let Rails/Sentry handle the response
        rescue StandardError => e
          # Log other exceptions with request context
          log_event(
            env,
            level: :error,
            event: 'request_error',
            error_class: e.class.name,
            error_message: e.message
          )
          raise # Re-raise to let Rails/Sentry handle the response
        end
      end

      private

      def log_event(env, event:, level:, client_ip: nil, **custom_fields)
        # WARNING: Calling .remote_ip on the request will raise an error
        # if this is a remote IP spoofing attack. It's still safe to call
        # any other methods.
        request = ActionDispatch::Request.new(env)
        log_data = {
          src: 'rails',
          evt: event,
          level: level,
          request_id: request.request_id,
          client_ip: client_ip || request.remote_ip,
          path: request.path,
          method: request.method,
          user_agent: request.user_agent,
          referer: request.referer,
          **custom_fields,
        }
        # We send a hash to the Rails log formatter which scrubs sensitive data,
        # adds tags, and then serializes it as JSON.
        Rails.logger.public_send(level, log_data)
      end
    end
  end
end
