# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RackErrorHandler
      # The structured lines for errors raised while Rails handles a request. Each error is logged once:
      # security errors from the app by DebugExceptions' interceptor, anything else that gets past
      # ShowExceptions by the middleware. Rails still turns each error into its usual response.
      module ErrorLines
        extend T::Sig

        CSRF_ERROR_NAMES = T.let(
          ["ActionController::InvalidAuthenticityToken", "ActionController::InvalidCrossOriginRequest"].freeze,
          T::Array[String]
        )

        sig { returns(T::Boolean) }
        def self.enabled?
          LogStruct.enabled? && LogStruct.config.integrations.enable_rack_error_handler
        end

        # For DebugExceptions.register_interceptor: CSRF and IP spoofing errors from the app, which
        # ShowExceptions would otherwise turn into a response before any middleware saw them.
        # Other errors are left to Rails' own logging and error reporting.
        sig { params(request: ::ActionDispatch::Request, error: Exception).void }
        def self.intercept(request, error)
          return unless enabled?
          return unless security_error?(error)
          return if LoggedErrors.logged?(error)

          log_security_error(request, error)
        end

        # An error that got past ShowExceptions (or came from a middleware outside it)
        sig { params(request: ::ActionDispatch::Request, error: StandardError).void }
        def self.log_escaped(request, error)
          return unless enabled?
          return if LoggedErrors.logged?(error)
          return log_security_error(request, error) if security_error?(error)

          LoggedErrors.mark(error)
          LogStruct.error(
            Log::Error.new(
              source: Source::Rails,
              error_class: error.class,
              message: error.message,
              backtrace: error.backtrace,
              path: request.path,
              http_method: request.method,
              source_ip: source_ip(request),
              user_agent: request.user_agent,
              referer: StringScrubber.without_query(request.referer)
            )
          )
        end

        # An error the app didn't handle, which DebugExceptions logs before ShowExceptions renders Rails'
        # error page: at config.action_dispatch.debug_exception_log_level (fatal by default), with the
        # trace Rails would log and the response's status. A security error already has its own line.
        sig { params(request: ::ActionDispatch::Request, wrapper: T.untyped).void }
        def self.log_unhandled(request, wrapper)
          error = T.cast(wrapper.exception, Exception)
          return if LoggedErrors.logged?(error)

          LoggedErrors.mark(error)
          # Without a backtrace cleaner, Rails' trace is Thread::Backtrace::Locations
          trace = Array(wrapper.exception_trace).map(&:to_s)
          cause = error.cause
          line = Log::Error.new(
            source: Source::Rails,
            error_class: error.class,
            message: error.message,
            backtrace: trace.empty? ? error.backtrace : trace,
            path: request.path,
            http_method: request.method,
            source_ip: source_ip(request),
            user_agent: request.user_agent,
            referer: StringScrubber.without_query(request.referer),
            status: wrapper.status_code,
            cause_class: cause&.class&.name,
            cause_message: cause&.message
          )
          case request.get_header("action_dispatch.debug_exception_log_level")
          when ::Logger::DEBUG then LogStruct.debug(line)
          when ::Logger::INFO then LogStruct.info(line)
          when ::Logger::WARN then LogStruct.warn(line)
          when ::Logger::ERROR then LogStruct.error(line)
          else LogStruct.fatal(line)
          end
        end

        # A security line, and the error handled in the security_errors mode (reported by default)
        sig { params(request: ::ActionDispatch::Request, error: Exception).void }
        def self.log_security_error(request, error)
          LoggedErrors.mark(error)
          if ip_spoof_error?(error)
            LogStruct.warn(
              Log::Security::IPSpoof.new(
                path: request.path,
                http_method: request.method,
                user_agent: request.user_agent,
                referer: StringScrubber.without_query(request.referer),
                message: error.message,
                source_ip: request.ip,
                client_ip: request.get_header("HTTP_CLIENT_IP"),
                x_forwarded_for: request.x_forwarded_for,
                timestamp: Time.now
              )
            )
          else
            LogStruct.error(
              Log::Security::CSRFViolation.new(
                path: request.path,
                http_method: request.method,
                source_ip: source_ip(request),
                user_agent: request.user_agent,
                referer: StringScrubber.without_query(request.referer),
                message: error.message,
                timestamp: Time.now
              )
            )
          end
          reported = error.is_a?(StandardError) ? error : RuntimeError.new(error.message)
          LogStruct.handle_exception(reported, source: Source::Security, context: request_context(request), log: false)
        end

        sig { params(request: ::ActionDispatch::Request).returns(T::Hash[Symbol, T.untyped]) }
        def self.request_context(request)
          {
            path: request.path,
            method: request.method,
            user_agent: request.user_agent,
            referer: StringScrubber.without_query(request.referer)
          }
        end

        # The client's IP, as Rails works it out, or the connection's when Rails finds a spoofed one
        sig { params(request: ::ActionDispatch::Request).returns(T.nilable(String)) }
        def self.source_ip(request)
          request.remote_ip
        rescue ::ActionDispatch::RemoteIp::IpSpoofAttackError
          request.ip
        end

        sig { params(error: Exception).returns(T::Boolean) }
        def self.security_error?(error)
          ip_spoof_error?(error) || CSRF_ERROR_NAMES.include?(error.class.name)
        end

        sig { params(error: Exception).returns(T::Boolean) }
        def self.ip_spoof_error?(error)
          error.is_a?(::ActionDispatch::RemoteIp::IpSpoofAttackError)
        end
      end
    end
  end
end
