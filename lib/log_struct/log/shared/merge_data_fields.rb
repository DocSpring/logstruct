# typed: strict
# frozen_string_literal: true

require_relative "data_interface"
require_relative "serialize_common"
require_relative "../../log_keys"

module LogStruct
  module Log
    # Helper module for merging additional data into serialized logs
    module MergeDataFields
      extend T::Sig
      extend T::Helpers

      include SerializeCommon

      requires_ancestor { T::Struct }
      requires_ancestor { DataInterface }

      sig { params(hash: T::Hash[Symbol, T.untyped]).void }
      def merge_data_fields(hash)
        data.each do |key, value|
          hash[key.to_sym] = value
        end
      end
    end
  end
end
