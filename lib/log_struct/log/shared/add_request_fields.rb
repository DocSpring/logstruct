# typed: strict
# frozen_string_literal: true

require_relative "../interfaces/log_interface"
require_relative "../../log_keys"

module LogStruct
  module Log
    # Common log serialization method
    module AddRequestFields
      extend T::Sig
      extend T::Helpers

      requires_ancestor { RequestInterface }

      # Helper method to serialize request fields
      sig { params(hash: T::Hash[Symbol, T.untyped]).void }
      def add_request_fields(hash)
        # Add request-specific fields if they're present
        hash[LogKeys::PATH] = path if path
        hash[LogKeys::METHOD] = http_method if http_method # Use `method` in JSON
        hash[LogKeys::SOURCE_IP] = source_ip if source_ip
        hash[LogKeys::USER_AGENT] = user_agent if user_agent
        hash[LogKeys::REFERER] = referer if referer
        hash[LogKeys::REQUEST_ID] = request_id if request_id
      end
    end
  end
end
