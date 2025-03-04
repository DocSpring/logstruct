# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    # Common interface for request-related fields
    # Used by both Request and Security logs to ensure consistency
    module RequestInterface
      extend T::Helpers

      interface!

      # Common request fields
      sig { abstract.returns(T.nilable(String)) }
      def path; end

      sig { abstract.returns(T.nilable(String)) }
      def http_method; end

      sig { abstract.returns(T.nilable(String)) }
      def source_ip; end

      sig { abstract.returns(T.nilable(String)) }
      def user_agent; end

      sig { abstract.returns(T.nilable(String)) }
      def referer; end

      sig { abstract.returns(T.nilable(String)) }
      def request_id; end
    end
  end
end
