# typed: strict
# frozen_string_literal: true

require_relative "configuration/error_handling_modes"
require_relative "configuration/integrations"
require_relative "configuration/filters"

module LogStruct
  module Untyped
    # Ruby-style configuration API that uses symbols and hashes
    class Configuration
      extend T::Sig

      sig { params(config: LogStruct::Configuration).void }
      def initialize(config)
        @config = T.let(config, LogStruct::Configuration)
        @error_handling_modes = T.let(Configuration::ErrorHandlingModes.new(config.error_handling_modes), Configuration::ErrorHandlingModes)
        @integrations = T.let(Configuration::Integrations.new(config.integrations), Configuration::Integrations)
        @filters = T.let(Configuration::Filters.new(config.filters), Configuration::Filters)
      end

      # -------------------------------------------------------------------------------------
      # Error Handling
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::ErrorHandlingModes) }
      attr_reader :error_handling_modes

      # -------------------------------------------------------------------------------------
      # Integrations
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::Integrations) }
      attr_reader :integrations

      # -------------------------------------------------------------------------------------
      # Filters
      # -------------------------------------------------------------------------------------

      sig { returns(Configuration::Filters) }
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

      sig { params(handler: LogStruct::Handlers::ExceptionReporter).void }
      def exception_reporting_handler=(handler)
        @config.exception_reporting_handler = handler
      end

      # Support for hash-based configuration
      sig { params(settings: T::Hash[Symbol, T.untyped]).void }
      def configure(settings)
        settings.each do |key, value|
          case key
          when :enabled then self.enabled = T.cast(value, T::Boolean)
          when :environments then self.environments = T.cast(value, T::Array[Symbol])
          when :local_environments then self.local_environments = T.cast(value, T::Array[Symbol])
          when :exception_reporting_handler then self.exception_reporting_handler = T.cast(value, LogStruct::Handlers::ExceptionReporter)
          when :error_handling_modes
            if value.is_a?(Hash)
              error_handling_modes.configure(value)
            else
              raise ArgumentError, "error_handling_modes must be a Hash"
            end
          when :integrations
            if value.is_a?(Hash)
              integrations.configure(value)
            else
              raise ArgumentError, "integrations must be a Hash"
            end
          when :filters
            if value.is_a?(Hash)
              filters.configure(value)
            else
              raise ArgumentError, "filters must be a Hash"
            end
          else
            raise ArgumentError, "Unknown configuration setting: #{key}"
          end
        end
      end
    end
  end
end
