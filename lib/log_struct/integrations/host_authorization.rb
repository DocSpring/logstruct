# typed: strict
# frozen_string_literal: true

require "action_dispatch/middleware/host_authorization"
require_relative "../enums/log_event"

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
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless config.enabled
        return unless config.integrations.enable_host_authorization

        # Define the response app as a separate variable to fix block alignment
        response_app = lambda do |env|
          request = ::ActionDispatch::Request.new(env)
          # Include the blocked hosts app configuration in the log entry
          # This can be helpful later when reviewing logs.
          blocked_hosts = env["action_dispatch.blocked_hosts"]

          # Create a structured security log entry
          security_log = Log::Security.new(
            event: LogEvent::BlockedHost,
            message: "Blocked host detected: #{request.host}",
            blocked_host: request.host,
            client_ip: request.ip,
            x_forwarded_for: request.x_forwarded_for,
            http_method: request.method,
            path: request.path,
            user_agent: request.user_agent,
            data: {
              allowed_hosts: blocked_hosts.allowed_hosts,
              allow_ip_hosts: blocked_hosts.allow_ip_hosts
            }
          )

          # Log and then return blocked host response
          LogStruct.log(security_log)

          # Use the pre-defined headers and response
          [FORBIDDEN_STATUS, RESPONSE_HEADERS, [RESPONSE_HTML]]
        end

        # Replace the default HostAuthorization app with our custom app that logs
        # TODO: Add an RBI override for this method since it's not detected by Sorbet
        T.unsafe(::ActionDispatch::HostAuthorization).blocked_response_app = response_app
      end
    end
  end
end
