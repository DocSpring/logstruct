# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    # Common log serialization method
    module LogSerialization
      extend T::Sig
      extend T::Helpers

      requires_ancestor { LogInterface }

      # Convert the log entry to a hash for serialization
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def common_serialize
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3)
        }
        hash[:msg] = msg if msg
        hash
      end
    end
  end
end
