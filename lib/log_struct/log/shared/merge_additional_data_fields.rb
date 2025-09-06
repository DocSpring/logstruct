# typed: strict
# frozen_string_literal: true

require_relative "../../log_keys"
require_relative "../interfaces/additional_data_field"

module LogStruct
  module Log
    # Helper module for merging additional data into serialized logs
    module MergeAdditionalDataFields
      extend T::Sig
      extend T::Helpers

      requires_ancestor { T::Struct }
      requires_ancestor { Interfaces::AdditionalDataField }

      sig { params(hash: T::Hash[Symbol, T.untyped]).void }
      def merge_additional_data_fields(hash)
        additional_data.each do |key, value|
          hash[key.to_sym] = value
        end
      end
    end
  end
end
