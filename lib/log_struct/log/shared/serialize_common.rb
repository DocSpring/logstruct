# typed: strict
# frozen_string_literal: true

require_relative "../../enums/log_field"
require_relative "../interfaces/common_fields"

module LogStruct
  module Log
    # Common log serialization method
    module SerializeCommon
      extend T::Sig
      extend T::Helpers

      requires_ancestor { Interfaces::CommonFields }

      # Convert the log entry to a hash for serialization.
      # (strict param is unused, but need same signature as default T::Struct.serialize)
      sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize_common(strict = true)
        {
          LogField::Source.serialize => source.serialize.to_s,
          LogField::Event.serialize => event.serialize.to_s,
          LogField::Level.serialize => level.serialize.to_s,
          LogField::Timestamp.serialize => timestamp.iso8601(3)
        }
      end

      # Override as_json to use our custom serialize method instead of default T::Struct serialization
      sig { params(options: T.untyped).returns(T::Hash[String, T.untyped]) }
      def as_json(options = nil)
        # Convert symbol keys to strings for JSON
        serialize.transform_keys(&:to_s)
      end
    end
  end
end
