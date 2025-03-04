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

    @@instance = T.let(nil, T.nilable(Configuration))

    prop :error_handling, ErrorHandling
    prop :integrations, Integrations
    prop :filters, Filters

    sig { returns(Configuration) }
    def self.instance
      @@instance ||= new(
        error_handling: ErrorHandling.new,
        integrations: Integrations.new,
        filters: Filters.new
      )
    end

    sig { returns(Configuration) }
    def self.config
      instance
    end

    sig { returns(Configuration) }
    def self.configuration
      instance
    end

    sig { returns(Configuration) }
    def self.configuration_typed
      instance
    end

    sig { params(block: T.proc.params(config: Configuration).void).void }
    def self.configure_typed(&block)
      yield(instance)
    end

    sig { params(block: T.proc.params(config: Configuration::Untyped).void).void }
    def self.configure(&block)
      config = Configuration::Untyped.instance
      yield(config)
      config.apply_to_typed
    end

    # -------------------------------------------------------------------------------------
    # Core Settings
    # -------------------------------------------------------------------------------------

    # Environments where LogStruct should be enabled automatically
    # Default: [:production]
    prop :environments, T::Array[Symbol]

    # Enable or disable LogStruct manually
    # Default: true
    prop :enabled, T::Boolean

    # -------------------------------------------------------------------------------------
    # Error Handling
    # -------------------------------------------------------------------------------------

    # Environments where errors should be raised locally
    # Default: [:test, :development]
    prop :local_environments, T::Array[Symbol]

    sig { void }
    def initialize
      super(
        error_handling: ErrorHandling.new,
        integrations: Integrations.new,
        filters: Filters.new,
        enabled: true,
        environments: [:test, :production],
        local_environments: [:test, :development]
      )
    end

    # Check if errors should be raised in the current environment
    sig { returns(T::Boolean) }
    def should_raise?
      local_environments.include?(::Rails.env.to_sym)
    end

    # Check if LogStruct should be enabled in the current environment
    sig { returns(T::Boolean) }
    def enabled_for_environment?
      enabled && environments.include?(::Rails.env.to_sym)
    end
  end
end
