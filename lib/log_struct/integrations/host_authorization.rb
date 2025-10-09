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

        # Define the response app as a separate variable to fix block alignment
        response_app = lambda do |env|
          request = ::ActionDispatch::Request.new(env)
          # Include the blocked hosts app configuration in the log entry
          # This can be helpful later when reviewing logs.
          blocked_hosts = env["action_dispatch.blocked_hosts"]

          # Build allowed_hosts array
          allowed_hosts_array = T.let(nil, T.nilable(T::Array[String]))
          if blocked_hosts.respond_to?(:allowed_hosts)
            allowed_hosts_array = blocked_hosts.allowed_hosts
          end

          # Get allow_ip_hosts value
          allow_ip_hosts_value = T.let(nil, T.nilable(T::Boolean))
          if blocked_hosts.respond_to?(:allow_ip_hosts)
            allow_ip_hosts_value = blocked_hosts.allow_ip_hosts
          end

          # Create structured log entry for blocked host
          log_entry = LogStruct::Log::Security::BlockedHost.new(
            message: "Blocked host detected: #{request.host}",
            blocked_host: request.host,
            path: request.path,
            http_method: request.method,
            source_ip: request.ip,
            user_agent: request.user_agent,
            referer: request.referer,
            request_id: request.request_id,
            x_forwarded_for: request.x_forwarded_for,
            allowed_hosts: allowed_hosts_array&.empty? ? nil : allowed_hosts_array,
            allow_ip_hosts: allow_ip_hosts_value
          )

          # Log the blocked host
          LogStruct.warn(log_entry)

          # Use pre-defined headers and response if we are only logging or reporting
          # Dup the headers so they can be modified by downstream middleware
          [FORBIDDEN_STATUS, RESPONSE_HEADERS.dup, [RESPONSE_HTML]]
        end

        # Merge our response_app into existing host_authorization config to preserve excludes
        existing = Rails.application.config.host_authorization
        unless existing.is_a?(Hash)
          existing = {}
        end
        existing = existing.dup
        existing[:response_app] = response_app
        Rails.application.config.host_authorization = existing

        true
      end
    end
  end
end
