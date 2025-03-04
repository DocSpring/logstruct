# typed: strict
# frozen_string_literal: true

require_relative "handlers"
require_relative "config_struct/error_handling_modes"
require_relative "config_struct/integrations"
require_relative "config_struct/filters"

module LogStruct
  # Core configuration class that provides a type-safe API
  class Configuration < T::Struct
    extend T::Sig

    # -------------------------------------------------------------------------------------
    # Props
    # -------------------------------------------------------------------------------------

    prop :enabled, T::Boolean, default: true
    prop :environments, T::Array[Symbol], factory: -> { [:test, :production] }
    prop :local_environments, T::Array[Symbol], factory: -> { [:development, :test] }
    const :integrations, ConfigStruct::Integrations, factory: -> { ConfigStruct::Integrations.new }
    const :filters, ConfigStruct::Filters, factory: -> { ConfigStruct::Filters.new }

    # Custom log scrubbing handler for any additional string scrubbing
    # Default: nil
    prop :string_scrubbing_handler, T.nilable(Handlers::StringScrubber)

    # Custom handler for exception reporting
    # Default: Errors are handled by MultiErrorReporter
    # (auto-detects Sentry, Bugsnag, Rollbar, Honeybadger, etc.)
    prop :exception_reporting_handler, T.nilable(Handlers::ExceptionReporter), default: nil

    # How to handle errors from various sources
    const :error_handling_modes,
      ConfigStruct::ErrorHandlingModes,
      factory: -> {
        ConfigStruct::ErrorHandlingModes.new
      }

    # -------------------------------------------------------------------------------------
    # Class Methods
    # -------------------------------------------------------------------------------------

    # Class‐instance variable
    @instance = T.let(nil, T.nilable(Configuration))

    sig { returns(Configuration) }
    def self.instance
      @instance ||= T.let(Configuration.new, T.nilable(Configuration))
    end
    
    sig { params(config: Configuration).void }
    def self.set_instance(config)
      @instance = config
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
