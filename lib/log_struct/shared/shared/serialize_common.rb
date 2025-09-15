# typed: strict
# frozen_string_literal: true

require_relative "../../enums/log_field"
require_relative "../interfaces/common_fields"

module LogStruct
  module Log
    module Shared
      module SerializeCommon
        extend T::Sig
        extend T::Helpers

        requires_ancestor { Interfaces::CommonFields }

        sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
        def serialize(strict = true)
          # Start with shared fields (source, event, level, timestamp)
          out = serialize_common(strict)

          # Merge event/base fields from the struct-specific hash
          field_hash = T.unsafe(self).to_h
          field_hash.each do |log_field, value|
            next if value.nil?
            key = T.cast(log_field, LogStruct::LogField).serialize
            out[key] = value.is_a?(::Time) ? value.iso8601 : value
          end

          # Merge any additional_data at top level if available
          if T.unsafe(self).respond_to?(:merge_additional_data_fields)
            # merge_additional_data_fields expects symbol keys
            T.unsafe(self).merge_additional_data_fields(out)
          end

          out
        end

        sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
        def serialize_common(strict = true)
          {
            LogField::Source.serialize => source.serialize.to_s,
            LogField::Event.serialize => event.serialize.to_s,
            LogField::Level.serialize => level.serialize.to_s,
            LogField::Timestamp.serialize => timestamp.iso8601(3)
          }
        end

        sig { params(options: T.untyped).returns(T::Hash[String, T.untyped]) }
        def as_json(options = nil)
          serialize.transform_keys(&:to_s)
        end
      end
    end
  end
end
