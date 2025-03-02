# typed: strict
# frozen_string_literal: true

module RailsStructuredLogging
  module LogTypes
    # Base log data class with common fields
    class BaseLogData
      sig { returns(Symbol) }
      attr_reader :src

      sig { returns(Symbol) }
      attr_reader :evt

      sig { returns(Time) }
      attr_reader :ts

      sig { returns(T.nilable(String)) }
      attr_reader :msg

      # Initialize with required fields
      sig do
        params(
          src: Symbol,
          evt: Symbol,
          ts: T.nilable(Time),
          msg: T.nilable(String)
        ).void
      end
      def initialize(src:, evt:, ts: nil, msg: nil)
        @src = src
        @evt = evt
        @ts = T.let(ts || Time.now, Time)
        @msg = msg
      end

      # Convert to hash for logging
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        {
          src: @src,
          evt: @evt,
          ts: @ts,
          msg: @msg
        }.compact
      end

      # Allow hash-like access to properties
      sig { params(key: Symbol).returns(T.untyped) }
      def [](key)
        to_h[key]
      end
    end
  end
end
