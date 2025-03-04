# typed: strict
# frozen_string_literal: true

require_relative "data_interface"

module LogStruct
  module Log
    # Helper module for merging additional data into serialized logs
    module MergeData
      extend T::Helpers

      # This module is designed to be included in T::Struct classes with a data field
      requires_ancestor { T::Struct }

      # Require the DataInterface to ensure data field exists
      requires_ancestor { DataInterface }

      # Convert the log entry to a hash for serialization
      # Overrides the default T::Struct#serialize method to merge additional data
      sig { returns(T::Hash[String, T.untyped]) }
      def serialize
        result = super
        # Merge the data hash if it's not empty
        if !data.empty?
          result.merge!(T::Hash[String, T.untyped].new(data.transform_keys(&:to_s)))
        end
        result
      end
    end
  end
end
