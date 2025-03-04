# typed: strict
# frozen_string_literal: true

require "action_dispatch/middleware/host_authorization"
require_relative "../enums/log_event"

module LogStruct
  module Integrations
    # Host Authorization integration for structured logging of blocked hosts
    module HostAuthorization
      class << self
        extend T::Sig
        # Set up host authorization logging
        sig { returns(T.nilable(TrueClass)) }
        def setup
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_host_authorization

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
              blocked_hosts: blocked_hosts,
              request_id: request.request_id,
              path: request.path,
              http_method: request.method,
              source_ip: request.remote_ip,
              user_agent: request.user_agent,
              referer: request.referer
            )
            # Log the structured data
            ::Rails.logger.warn(security_log)

            # Return a 403 Forbidden response
            [403, {"Content-Type" => "text/plain"}, ["Forbidden: Blocked Host"]]
          end

          # Assign the lambda to the host_authorization config
          ::Rails.application.config.host_authorization ||= {}
          ::Rails.application.config.host_authorization[:response_app] = response_app
        end
      end
    end
  end
end
