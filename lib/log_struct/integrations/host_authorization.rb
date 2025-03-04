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
            remote_ip: request.ip,
            forwarded_for: request.x_forwarded_for,
            http_method: request.method,
            path: request.path,
            url: request.url,
            user_agent: request.user_agent,
            allowed_hosts: blocked_hosts.allowed_hosts,
            allow_ip_hosts: blocked_hosts.allow_ip_hosts
          )

          # Log and then return blocked host response
          LogStruct.log(security_log)

          # Generate an appropriate blocked host response
          headers = {"Content-Type" => "text/html", "Content-Length" => "292"}

          [403, headers, ["<html><head><title>Blocked Host</title></head><body><h1>Blocked Host</h1><p>This host is not permitted to access this application.</p><p>If you are the administrator, check your configuration.</p></body></html>"]]
        end

        # Replace the default HostAuthorization app with our custom app that logs
        ::ActionDispatch::HostAuthorization.blocked_response_app = response_app
      end
    end
  end
end
