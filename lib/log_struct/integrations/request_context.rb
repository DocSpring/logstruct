# typed: strict
# frozen_string_literal: true

require_relative "request_context/middleware"

module LogStruct
  module Integrations
    # Request context integration that captures request_id for all logs
    module RequestContext
      extend T::Sig
      extend IntegrationInterface

      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless config.enabled

        # Insert after RequestId middleware so request_id is available
        ::Rails.application.middleware.insert_after(
          ::ActionDispatch::RequestId,
          Integrations::RequestContext::Middleware
        )

        true
      end
    end
  end
end
