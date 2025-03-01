# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative '../constants'

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Base log data struct with common fields
    class BaseLogData < T::Struct
      extend T::Sig

      const :src, Symbol
      const :evt, Symbol
      const :ts, T.nilable(Time), default: Time.now
      const :msg, T.nilable(String)

      # Allow additional data with string/symbol keys
      const :additional_data, T::Hash[T.any(Symbol, String), T.untyped], default: {}
    end
  end
end
