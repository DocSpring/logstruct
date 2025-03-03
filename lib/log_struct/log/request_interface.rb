# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    # Common interface for request-related fields
    # Used by both Request and Security logs to ensure consistency
    module RequestInterface
      extend T::Sig
      extend T::Helpers

      interface!

      # Common request fields
      sig { abstract.returns(T.nilable(String)) }
      def path
      end

      sig { abstract.returns(T.nilable(String)) }
      def http_method
      end

      sig { abstract.returns(T.nilable(String)) }
      def source_ip
      end

      sig { abstract.returns(T.nilable(String)) }
      def user_agent
      end

      sig { abstract.returns(T.nilable(String)) }
      def referer
      end

      sig { abstract.returns(T.nilable(String)) }
      def request_id
      end
    end

    # Helper module for serializing request fields
    # Can be included in classes that implement RequestInterface
    module RequestSerialization
      extend T::Sig
      extend T::Helpers

      requires_ancestor { RequestInterface }

      # Helper method to serialize common request fields
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def serialize_request_fields
        hash = {}

        # Add request-specific fields if they're present
        hash[:path] = path if path
        hash[:method] = http_method if http_method # Use `method` in JSON
        hash[:source_ip] = source_ip if source_ip
        hash[:user_agent] = user_agent if user_agent
        hash[:referer] = referer if referer
        hash[:request_id] = request_id if request_id

        hash
      end
    end
  end
end
