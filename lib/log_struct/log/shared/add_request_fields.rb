# typed: strict
# frozen_string_literal: true

require_relative "../../log_keys"
require_relative "../interfaces/request_fields"

module LogStruct
  module Log
    # Common log serialization method
    module AddRequestFields
      extend T::Sig
      extend T::Helpers

      requires_ancestor { Interfaces::RequestFields }

      # Helper method to serialize request fields
      sig { params(hash: T::Hash[Symbol, T.untyped]).void }
      def add_request_fields(hash)
        # Add request-specific fields if they're present
        hash[LOG_KEYS[:path]] = path if path
        hash[LOG_KEYS[:http_method]] = http_method if http_method # Use `method` in JSON
        hash[LOG_KEYS[:source_ip]] = source_ip if source_ip
        hash[LOG_KEYS[:user_agent]] = user_agent if user_agent
        hash[LOG_KEYS[:referer]] = referer if referer
        hash[LOG_KEYS[:request_id]] = request_id if request_id
      end
    end
  end
end
