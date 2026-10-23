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

        # Every line's own fields, and the request ID the formatter adds unless the line has one
        RESERVED_KEYS = T.let(
          [LogField::Source, LogField::Event, LogField::Level, LogField::Timestamp, LogField::RequestId].to_set(&:serialize).freeze,
          T::Set[Symbol]
        )

        NO_FIELD_KEYS = T.let(Set.new.freeze, T::Set[Symbol])

        # The keys of every field of the struct's type, set or not on this line, which additional_data can't
        # set: it would replace the field, or stand in for one the type didn't write. LogStruct's log types list
        # theirs. A custom type's serialize writes its own fields after merging additional_data, so they win.
        sig { overridable.returns(T::Set[Symbol]) }
        def field_keys
          NO_FIELD_KEYS
        end

        sig { params(hash: T::Hash[Symbol, T.untyped]).void }
        def merge_additional_data_fields(hash)
          ad = additional_data
          return unless ad
          ad.each_pair.with_index do |(key, value), index|
            break if index >= LogStruct.config.limits.max_hash_keys
            next if key.to_s.bytesize > LogStruct.config.limits.max_string_bytes

            sym_key = key.to_sym
            if RESERVED_KEYS.include?(sym_key) || field_keys.include?(sym_key)
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
