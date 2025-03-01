# frozen_string_literal: true
# typed: strict

module RailsStructuredLogging
  module Enums
    # Helper methods for enum classes
    module EnumHelpers
      extend T::Sig

      # Convert enum value to symbol for use in log data
      sig { returns(Symbol) }
      def to_sym
        serialize
      end

      # Convert enum value to string for use in log data
      sig { returns(String) }
      def to_s
        serialize.to_s
      end
    end
  end
end
