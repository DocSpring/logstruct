# typed: true
# frozen_string_literal: true

require "action_dispatch/middleware/host_authorization"

module LogStruct
  module Integrations
    # Host Authorization integration for structured logging of blocked hosts
    module HostAuthorizationResponseApp
      class << self
        # Set up host authorization logging
        def setup
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.host_authorization_enabled

          # Define the response app as a separate variable to fix block alignment
          response_app = lambda do |env|
            request = ::ActionDispatch::Request.new(env)
            blocked_hosts = env["action_dispatch.blocked_hosts"]

            # Log the blocked host attempt as a hash
            # (converted to JSON by the Rails log formatter)
            ::Rails.logger.warn(
              src: Enums::SourceType::Rails.serialize,
              evt: Enums::EventType::SecurityViolation.serialize,
              violation_type: Enums::ViolationType::BlockedHost.serialize,
              blocked_host: request.host,
              blocked_hosts: blocked_hosts,
              request_id: request.request_id,
              path: request.path,
              method: request.method,
              source_ip: request.remote_ip,
              user_agent: request.user_agent,
              referer: request.referer
            )

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
