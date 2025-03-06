# typed: strict
# frozen_string_literal: true

require_relative "../../log_keys"
require_relative "../interfaces/common_fields"

module LogStruct
  module Log
    # Common log serialization method
    module SerializeCommon
      extend T::Sig
      extend T::Helpers

      requires_ancestor { Interfaces::CommonFields }

      # Convert the log entry to a hash for serialization.
      # (strict param is unused, but need same signature as default T::Struct.serialize)
      sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize_common(strict = true)
        {
          LOG_KEYS[:source] => source.serialize,
          LOG_KEYS[:event] => event.serialize,
          LOG_KEYS[:timestamp] => timestamp.iso8601(3),
          LOG_KEYS[:level] => level.serialize
        }
      end
    end
  end
end
