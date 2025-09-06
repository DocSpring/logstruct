# typed: strict
# frozen_string_literal: true

require_relative "../../enums/level"

module LogStruct
  module Log
    module Interfaces
      # Public interface for custom app log types.
      # Allows String/Symbol for source and event so apps can define their own domains.
      module PublicCommonFields
        extend T::Sig
        extend T::Helpers

        interface!

        # Log level (defaults to Info in most structs)
        sig { abstract.returns(Level) }
        def level; end

        # Timestamp for the entry
        sig { abstract.returns(Time) }
        def timestamp; end

        # Custom serialize method returning symbol-keyed hash
        sig { abstract.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
        def serialize(strict = true); end
      end
    end
  end
end
