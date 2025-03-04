# typed: strict
# frozen_string_literal: true

require_relative "configuration/untyped"
require_relative "configuration/error_handling"
require_relative "configuration/integrations"
require_relative "configuration/filters"

module LogStruct
  # Core configuration class that provides a type-safe API
  class Configuration < T::Struct
    extend T::Sig

    # -------------------------------------------------------------------------------------
    # Props
    # -------------------------------------------------------------------------------------

    const :error_handling, ErrorHandling
    const :integrations, Integrations
    const :filters, Filters
    prop :enabled, T::Boolean, default: true
    prop :environments, T::Array[Symbol], default: [:test, :production]
    prop :local_environments, T::Array[Symbol], default: [:development, :test]

    # -------------------------------------------------------------------------------------
    # Class Methods
    # -------------------------------------------------------------------------------------

    class << self
      # Class‐instance variable
      @configuration = T.let(nil, T.nilable(Configuration))

      sig { returns(Configuration) }
      def configuration
        @configuration ||= T.let(Configuration.new(
          error_handling: ErrorHandling.new,
          integrations: Integrations.new,
          filters: Filters.new
        ),
          T.nilable(Configuration))
      end
    end

    # -------------------------------------------------------------------------------------
    # Serialization
    # -------------------------------------------------------------------------------------

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def serialize
      super.deep_symbolize_keys
    end
    alias_method :to_h, :serialize
  end
end
