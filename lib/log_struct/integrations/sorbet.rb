# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module LogStruct
  module Integrations
    # Integration for Sorbet runtime type checking error handlers
    # This module installs error handlers that report type errors through LogStruct
    # These handlers can be enabled/disabled using configuration
    module Sorbet
      extend T::Sig
      extend IntegrationInterface

      # Set up Sorbet error handlers to report errors through LogStruct
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless config.integrations.enable_sorbet_error_handler

        # Install inline type error handler
        # Called when T.let, T.cast, T.must, etc. fail
        T::Configuration.inline_type_error_handler = lambda do |error, _opts|
          LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
        end

        # Install call validation error handler
        # Called when method signature validation fails
        T::Configuration.call_validation_error_handler = lambda do |_signature, opts|
          error = TypeError.new(opts[:pretty_message])
          LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
        end

        # Install sig builder error handler
        # Called when there's a problem with a signature definition
        T::Configuration.sig_builder_error_handler = lambda do |error, _location|
          LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
        end

        # Install sig validation error handler
        # Called when there's a problem with a signature validation
        T::Configuration.sig_validation_error_handler = lambda do |error, _opts|
          LogStruct.handle_exception(error, source: LogStruct::Source::TypeChecking)
        end
      end
    end
  end
end
