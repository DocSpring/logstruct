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

      # Convert the log entry to a hash for serialization
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def serialize_common
        {
          LogKeys::SRC => source.serialize,
          LogKeys::EVT => event.serialize,
          LogKeys::TS => timestamp.iso8601(3),
          LogKeys::LVL => level.serialize
        }
      end
    end
  end
end
