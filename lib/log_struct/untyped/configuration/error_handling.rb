# typed: strict
# frozen_string_literal: true

module LogStruct
  module Untyped
    class Configuration
      class ErrorHandling
        extend T::Sig

        sig { params(typed: LogStruct::Configuration::ErrorHandling).void }
        def initialize(typed)
          @typed = T.let(typed, LogStruct::Configuration::ErrorHandling)
        end

        sig { params(mode: Symbol).void }
        def type_errors=(mode)
          @typed.type_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def logstruct_errors=(mode)
          @typed.logstruct_errors = mode_from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def standard_errors=(mode)
          @typed.standard_errors = mode_from_symbol(mode)
        end

        sig { params(handler: LogStruct::CustomHandlers::ExceptionReporter).void }
        def exception_reporting_handler=(handler)
          @typed.exception_reporting_handler = handler
        end

        sig { params(settings: T::Hash[Symbol, T.untyped]).void }
        def configure(settings)
          settings.each do |key, value|
            case key
            when :type_errors then self.type_errors = T.cast(value, Symbol)
            when :logstruct_errors then self.logstruct_errors = T.cast(value, Symbol)
            when :standard_errors then self.standard_errors = T.cast(value, Symbol)
            when :exception_reporting_handler then self.exception_reporting_handler = T.cast(value, LogStruct::CustomHandlers::ExceptionReporter)
            else
              raise ArgumentError, "Unknown error handling setting: #{key}"
            end
          end
        end

        private

        sig { params(mode: Symbol).returns(LogStruct::Configuration::ErrorHandling::Mode) }
        def mode_from_symbol(mode)
          LogStruct::Configuration::ErrorHandling::Mode.from_symbol(mode)
        end
      end
    end
  end
end
