# typed: strict
# frozen_string_literal: true

require_relative "handlers"
require_relative "configuration/error_handling_modes"
require_relative "configuration/integrations"
require_relative "configuration/filters"
require_relative "untyped/configuration"

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
    const :integrations, Configuration::Integrations, factory: -> { Configuration::Integrations.new }
    const :filters, Configuration::Filters, factory: -> { Configuration::Filters.new }

    # Custom log scrubbing handler for any additional string scrubbing
    # Default: nil
    prop :string_scrubbing_handler, T.nilable(LogStruct::CustomHandlers::StringScrubber)

    # Custom handler for exception reporting
    # Default: Errors are handled by LogStruct::MultiErrorReporter
    # (auto-detects Sentry, Bugsnag, Rollbar, Honeybadger, etc.)
    prop :exception_reporting_handler, T.nilable(Handlers::ExceptionReporter), default: nil

    # How to handle errors from various sources
    const :error_handling_modes,
      Configuration::ErrorHandlingModes,
      factory: -> {
        Configuration::ErrorHandlingModes.new
      }

    # -------------------------------------------------------------------------------------
    # Class Methods
    # -------------------------------------------------------------------------------------

    # Class‐instance variable
    @configuration = T.let(nil, T.nilable(Configuration))

    sig { returns(Configuration) }
    def self.configuration
      @configuration ||= T.let(Configuration.new, T.nilable(Configuration))
    end

    # -------------------------------------------------------------------------------------
    # Serialization
    # -------------------------------------------------------------------------------------

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def serialize
      super.deep_symbolize_keys
    end
    alias_method :to_h, :serialize

    # -------------------------------------------------------------------------------------
    # Environment Detection
    # -------------------------------------------------------------------------------------

    sig { returns(T::Boolean) }
    def should_raise?
      environments.exclude?(::Rails.env.to_sym)
    end
  end
end
