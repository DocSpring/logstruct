# typed: strict
# frozen_string_literal: true

require_relative "../../enums/log_field"
require_relative "../interfaces/public_common_fields"

module LogStruct
  module Log
    # Common serialization for public custom log structs with string/symbol source/event
    module SerializeCommonPublic
      extend T::Sig
      extend T::Helpers

      requires_ancestor { Interfaces::PublicCommonFields }
      requires_ancestor { Kernel }

      sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize_common_public(strict = true)
        unless respond_to?(:source) && respond_to?(:event)
          raise ArgumentError, "Public log struct must define #source and #event"
        end

        src_val = public_send(:source)
        evt_val = public_send(:event)
        src = src_val.respond_to?(:serialize) ? src_val.public_send(:serialize).to_s : src_val.to_s
        evt = evt_val.respond_to?(:serialize) ? evt_val.public_send(:serialize).to_s : evt_val.to_s
        lvl = level.serialize.to_s
        ts = timestamp.iso8601(3)

        {
          LogField::Source.serialize => src,
          LogField::Event.serialize => evt,
          LogField::Level.serialize => lvl,
          LogField::Timestamp.serialize => ts
        }
      end

      sig { params(options: T.untyped).returns(T::Hash[String, T.untyped]) }
      def as_json(options = nil)
        serialize.transform_keys(&:to_s)
      end
    end
  end
end
