# typed: strict
# frozen_string_literal: true

require_relative "untyped/error_handling"
require_relative "untyped/integrations"
require_relative "untyped/filters"

module LogStruct
  class Configuration
    # Ruby-style configuration API that uses symbols and hashes
    class Untyped
      extend T::Sig

      sig { params(config: Configuration).void }
      def initialize(config)
        @config = T.let(config, Configuration)
        @error_handling = T.let(Untyped::ErrorHandling.new(config.error_handling), Untyped::ErrorHandling)
        @integrations = T.let(Untyped::Integrations.new(config.integrations), Untyped::Integrations)
        @filters = T.let(Untyped::Filters.new(config.filters), Untyped::Filters)
      end

      # -------------------------------------------------------------------------------------
      # Error Handling
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::Untyped::ErrorHandling) }
      attr_reader :error_handling

      # -------------------------------------------------------------------------------------
      # Integrations
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::Untyped::Integrations) }
      attr_reader :integrations

      # -------------------------------------------------------------------------------------
      # Filters
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::Untyped::Filters) }
      attr_reader :filters

      # -------------------------------------------------------------------------------------
      # Core Settings
      # -------------------------------------------------------------------------------------

      sig { params(enabled: T::Boolean).void }
      def enabled=(enabled)
        @config.enabled = enabled
      end

      sig { params(environments: T::Array[Symbol]).void }
      def environments=(environments)
        @config.environments = environments
      end

      sig { params(environments: T::Array[Symbol]).void }
      def local_environments=(environments)
        @config.local_environments = environments
      end
    end
  end
end
