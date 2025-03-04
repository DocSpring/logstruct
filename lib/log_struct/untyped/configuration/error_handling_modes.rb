# typed: strict
# frozen_string_literal: true

module LogStruct
  module Untyped
    class Configuration
      class ErrorHandlingModes
        extend T::Sig

        sig { params(typed: LogStruct::Configuration::ErrorHandlingModes).void }
        def initialize(typed)
          @typed = T.let(typed, LogStruct::Configuration::ErrorHandlingModes)
        end

        # Error handling modes for different error sources
        sig { params(mode: Symbol).void }
        def type_checking_errors=(mode)
          @typed.type_checking_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def logstruct_errors=(mode)
          @typed.logstruct_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def security_errors=(mode)
          @typed.security_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def request_errors=(mode)
          @typed.request_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def application_errors=(mode)
          @typed.application_errors = mode_from_symbol(mode)
        end

        sig { params(settings: T::Hash[Symbol, T.untyped]).void }
        def configure(settings)
          settings.each do |key, value|
            case key
            when :type_checking_errors then self.type_checking_errors = T.cast(value, Symbol)
            when :logstruct_errors then self.logstruct_errors = T.cast(value, Symbol)
            when :security_errors then self.security_errors = T.cast(value, Symbol)
            when :request_errors then self.request_errors = T.cast(value, Symbol)
            when :application_errors then self.application_errors = T.cast(value, Symbol)
            else
              raise ArgumentError, "Unknown error handling setting: #{key}"
            end
          end
        end

        private

        sig { params(mode: Symbol).returns(LogStruct::ErrorHandlingMode) }
        def mode_from_symbol(mode)
          LogStruct::ErrorHandlingMode.from_symbol(mode)
        end
      end
    end
  end
end
