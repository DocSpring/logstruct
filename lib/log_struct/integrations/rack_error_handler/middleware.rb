# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RackErrorHandler
      # Custom middleware to enhance Rails error logging with JSON format and request details
      class Middleware
        extend T::Sig

        # IP Spoofing error response
        IP_SPOOF_HTML = T.let(
          "<html><head><title>IP Spoofing Detected</title></head><body>" \
          "<h1>Forbidden</h1>" \
          "<p>IP spoofing detected. This request has been blocked for security reasons.</p>" \
          "</body></html>",
          String
        )

        # CSRF error response
        CSRF_HTML = T.let(
          "<html><head><title>CSRF Error</title></head><body>" \
          "<h1>Forbidden</h1>" \
          "<p>Invalid authenticity token. This request has been blocked to prevent cross-site request forgery.</p>" \
          "</body></html>",
          String
        )

        # Response headers calculated at load time
        IP_SPOOF_HEADERS = T.let(
          {
            "Content-Type" => "text/html",
            "Content-Length" => IP_SPOOF_HTML.bytesize.to_s
          }.freeze,
          T::Hash[String, String]
        )

        CSRF_HEADERS = T.let(
          {
            "Content-Type" => "text/html",
            "Content-Length" => CSRF_HTML.bytesize.to_s
          }.freeze,
          T::Hash[String, String]
        )

        # HTTP status code for forbidden responses
        FORBIDDEN_STATUS = T.let(403, Integer)

        sig { params(app: T.untyped).void }
        def initialize(app)
          @app = app
        end

        sig { params(env: T.untyped).returns(T.untyped) }
        def call(env)
          return @app.call(env) unless LogStruct.enabled?

          request = ::ActionDispatch::Request.new(env)

          begin
            # Trigger the same spoofing checks that ActionDispatch::RemoteIp performs after
            # it is initialized in the middleware stack. We run this manually because we
            # execute before that middleware and still want spoofing attacks to surface here.
            perform_remote_ip_check!(request)

            @app.call(env)
          rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError => ip_spoof_error
            # Create a security log for IP spoofing
            security_log = Log::Security::IPSpoof.new(
              path: env["PATH_INFO"],
              http_method: env["REQUEST_METHOD"],
              user_agent: env["HTTP_USER_AGENT"],
              referer: env["HTTP_REFERER"],
              request_id: request.request_id,
              message: ip_spoof_error.message,
              client_ip: env["HTTP_CLIENT_IP"],
              x_forwarded_for: env["HTTP_X_FORWARDED_FOR"],
              timestamp: Time.now
            )

            ::Rails.logger.warn(security_log)

            [FORBIDDEN_STATUS, IP_SPOOF_HEADERS.dup, [IP_SPOOF_HTML]]
          rescue => error
            if csrf_error?(error)
              # Create a security log for CSRF error
              security_log = Log::Security::CSRFViolation.new(
                path: request.path,
                http_method: request.method,
                source_ip: request.remote_ip,
                user_agent: request.user_agent,
                referer: request.referer,
                request_id: request.request_id,
                message: error.message,
                timestamp: Time.now
              )
              LogStruct.error(security_log)

              # Report to error reporting service and/or re-raise
              context = extract_request_context(env, request)
              LogStruct.handle_exception(error, source: Source::Security, context: context)

              # If handle_exception raised an exception then Rails will deal with it (e.g. config.exceptions_app)
              # If we are only logging or reporting these security errors, then return a default response
              [FORBIDDEN_STATUS, CSRF_HEADERS.dup, [CSRF_HTML]]
            else
              # Extract request context for error reporting
              context = extract_request_context(env, request)

              # Create and log a structured exception with request context
              exception_log = Log.from_exception(Source::Rails, error, context)
              LogStruct.error(exception_log)

              # Re-raise any standard errors to let Rails or error reporter handle it.
              # Rails will also log the request details separately
              raise error
            end
          end
        end

        private

        sig { params(request: ::ActionDispatch::Request).void }
        def perform_remote_ip_check!(request)
          action_dispatch_config = ::Rails.application.config.action_dispatch
          check_ip = action_dispatch_config.ip_spoofing_check
          return unless check_ip

          proxies = normalized_trusted_proxies(action_dispatch_config.trusted_proxies)

          ::ActionDispatch::RemoteIp::GetIp
            .new(request, check_ip, proxies)
            .to_s
        end

        sig { params(env: T::Hash[String, T.untyped], request: T.nilable(::ActionDispatch::Request)).returns(T::Hash[Symbol, T.untyped]) }
        def extract_request_context(env, request = nil)
          request ||= ::ActionDispatch::Request.new(env)
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

        sig { params(error: StandardError).returns(T::Boolean) }
        def csrf_error?(error)
          error_name = error.class.name
          error_name == "ActionController::InvalidAuthenticityToken" ||
            error_name == "ActionController::InvalidCrossOriginRequest"
        end

        sig { params(configured_proxies: T.untyped).returns(T.untyped) }
        def normalized_trusted_proxies(configured_proxies)
          if configured_proxies.nil? || (configured_proxies.respond_to?(:empty?) && configured_proxies.empty?)
            return ::ActionDispatch::RemoteIp::TRUSTED_PROXIES
          end

          return configured_proxies if configured_proxies.respond_to?(:any?)

          raise(
            ArgumentError,
            <<~EOM
              Setting config.action_dispatch.trusted_proxies to a single value isn't
              supported. Please set this to an enumerable instead. For
              example, instead of:

              config.action_dispatch.trusted_proxies = IPAddr.new("10.0.0.0/8")

              Wrap the value in an Array:

              config.action_dispatch.trusted_proxies = [IPAddr.new("10.0.0.0/8")]

              Note that passing an enumerable will *replace* the default set of trusted proxies.
            EOM
          )
        end
      end
    end
  end
end
