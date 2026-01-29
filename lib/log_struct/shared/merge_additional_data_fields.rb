# typed: strict
# frozen_string_literal: true

require_relative "interfaces/additional_data_field"
require_relative "../enums/source"

module LogStruct
  module Log
    module Shared
      module MergeAdditionalDataFields
        extend T::Sig
        extend T::Helpers

        requires_ancestor { T::Struct }
        requires_ancestor { Interfaces::AdditionalDataField }

        # Reserved keys that cannot be overwritten by additional_data.
        # These are the core log structure fields that must not be modified.
        RESERVED_KEYS = T.let(%i[src evt lvl ts].freeze, T::Array[Symbol])

        sig { params(hash: T::Hash[Symbol, T.untyped]).void }
        def merge_additional_data_fields(hash)
          ad = additional_data
          return unless ad
          ad.each do |key, value|
            sym_key = key.to_sym
            if RESERVED_KEYS.include?(sym_key)
              LogStruct.handle_exception(
                ArgumentError.new("additional_data attempted to overwrite reserved key: #{sym_key}"),
                source: Source::Internal
              )
              next
            end
            hash[sym_key] = value
          end
        end
      end
    end
  end
end
