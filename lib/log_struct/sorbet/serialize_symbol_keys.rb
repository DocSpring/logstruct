# typed: strict
# frozen_string_literal: true

module LogStruct
  module Sorbet
    module SerializeSymbolKeys
      extend T::Sig
      extend T::Helpers

      requires_ancestor { T::Struct }

      sig { params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        super.deep_symbolize_keys
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        serialize
      end
    end
  end
end
