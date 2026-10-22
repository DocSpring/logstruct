# typed: strict
# frozen_string_literal: true

require_relative "interfaces/additional_data_field"
require_relative "../enums/source"
require_relative "../enums/log_field"

module LogStruct
  module Log
    module Shared
      module MergeAdditionalDataFields
        extend T::Sig
        extend T::Helpers

        requires_ancestor { T::Struct }
        requires_ancestor { Interfaces::AdditionalDataField }

        RESERVED_KEYS = T.let(LogField.values.map(&:serialize).to_set.freeze, T::Set[Symbol])

        sig { params(hash: T::Hash[Symbol, T.untyped]).void }
        def merge_additional_data_fields(hash)
          ad = additional_data
          return unless ad
          ad.each_pair.with_index do |(key, value), index|
            break if index >= LogStruct.config.limits.max_hash_keys
            next if key.to_s.bytesize > LogStruct.config.limits.max_string_bytes

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
