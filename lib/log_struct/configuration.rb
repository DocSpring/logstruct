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

    const :error_handling_modes, Configuration::ErrorHandlingModes
    const :integrations, Configuration::Integrations
    const :filters, Configuration::Filters
    prop :enabled, T::Boolean, default: true
    prop :environments, T::Array[Symbol], default: [:test, :production]
    prop :local_environments, T::Array[Symbol], default: [:development, :test]
    
    # Custom handler for exception reporting
    # Default: Errors are handled by LogStruct::MultiErrorReporter 
    # (auto-detects Sentry, Bugsnag, Rollbar, Honeybadger, etc.)
    prop :exception_reporting_handler, Handlers::ExceptionReporter

    # -------------------------------------------------------------------------------------
    # Class Methods
    # -------------------------------------------------------------------------------------

    class << self
      # Class‐instance variable
      @configuration = T.let(nil, T.nilable(Configuration))

      sig { returns(Configuration) }
      def configuration
        @configuration ||= T.let(Configuration.new(
          error_handling: Configuration::ErrorHandling.new,
          integrations: Configuration::Integrations.new,
          filters: Configuration::Filters.new
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

    # -------------------------------------------------------------------------------------
    # Environment Detection
    # -------------------------------------------------------------------------------------

    sig { returns(T::Boolean) }
    def should_raise?
      environments.exclude?(Rails.env.to_sym)
    end
  end
end
