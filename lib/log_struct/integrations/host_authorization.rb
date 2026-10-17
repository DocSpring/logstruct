# typed: strict
# frozen_string_literal: true

require "action_dispatch/middleware/host_authorization"
require_relative "../enums/event"
require_relative "../log/security/blocked_host"

module LogStruct
  module Integrations
    # Host Authorization integration for structured logging of blocked hosts
    module HostAuthorization
      extend T::Sig
      extend IntegrationInterface

      RESPONSE_HTML = T.let(
        "<html><head><title>Blocked Host</title></head><body>" \
        "<h1>Blocked Host</h1>" \
        "<p>This host is not permitted to access this application.</p>" \
        "<p>If you are the administrator, check your configuration.</p>" \
        "</body></html>",
        String
      )
      RESPONSE_HEADERS = T.let(
        {
          "Content-Type" => "text/html",
          "Content-Length" => RESPONSE_HTML.bytesize.to_s
        }.freeze,
        T::Hash[String, String]
      )
      FORBIDDEN_STATUS = T.let(403, Integer)

      # Set up host authorization logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless config.enabled
        return nil unless config.integrations.enable_host_authorization

        # Merge our response_app into existing host_authorization config to preserve excludes
        existing = Rails.application.config.host_authorization
        unless existing.is_a?(Hash)
          existing = {}
        end
        existing = existing.dup
        app_response_app = existing[:response_app]
        # Set up once: don't wrap our own response app again
        app_response_app = app_response_app.app_response_app if app_response_app.is_a?(ResponseApp)
        existing[:response_app] = ResponseApp.new(app_response_app)
        Rails.application.config.host_authorization = existing

        true
      end

      # Logs the blocked host, then responds with the app's own response_app if it set one
      class ResponseApp
        extend T::Sig

        sig { returns(T.untyped) }
        attr_reader :app_response_app

        sig { params(app_response_app: T.untyped).void }
        def initialize(app_response_app)
          @app_response_app = app_response_app
        end

        sig { params(env: T::Hash[String, T.untyped]).returns(T.untyped) }
        def call(env)
          begin
            log_blocked_host(env)
          rescue => e
            LogStruct.handle_exception(e, source: LogStruct::Source::Internal, context: {integration: :host_authorization})
          end
          return @app_response_app.call(env) if @app_response_app

          # Dup the headers so they can be modified by downstream middleware
          [FORBIDDEN_STATUS, RESPONSE_HEADERS.dup, [RESPONSE_HTML]]
        end

        private

        sig { params(env: T::Hash[String, T.untyped]).void }
        def log_blocked_host(env)
          request = ::ActionDispatch::Request.new(env)
          # The hosts Rails blocked: the Host header, and X-Forwarded-Host when it's set
          blocked_hosts = Array(env["action_dispatch.blocked_hosts"]).map(&:to_s)

          log_entry = LogStruct::Log::Security::BlockedHost.new(
            message: "Blocked host detected: #{request.host}",
            blocked_host: request.host,
            blocked_hosts: blocked_hosts.empty? ? nil : blocked_hosts,
            path: request.path,
            http_method: request.method,
            source_ip: request.ip,
            user_agent: request.user_agent,
            referer: StringScrubber.without_query(request.referer),
            x_forwarded_for: request.x_forwarded_for
          )

          LogStruct.warn(log_entry)
        end
      end
    end
  end
end
