# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
module LogStruct
  module Log
    # Common log serialization method
    module LogSerialization
      extend T::Helpers

      requires_ancestor { LogInterface }

      # Convert the log entry to a hash for serialization
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def common_serialize
        {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          lvl: lvl.serialize
        }
      end
    end
  end
end
