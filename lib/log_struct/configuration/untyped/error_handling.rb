# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class Untyped
      class ErrorHandling
        sig { params(typed: Configuration::ErrorHandling).void }
        def initialize(typed)
          @typed = typed
        end

        sig { params(mode: Symbol).void }
        def type_errors=(mode)
          @typed.type_errors = ErrorHandlingMode.from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def logstruct_errors=(mode)
          @typed.logstruct_errors = ErrorHandlingMode.from_symbol(mode)
        end

        sig { params(mode: Symbol).void }
        def standard_errors=(mode)
          @typed.standard_errors = ErrorHandlingMode.from_symbol(mode)
        end

        sig { params(settings: T::Hash[Symbol, Symbol]).void }
        def configure(settings)
          settings.each do |error_type, mode|
            case error_type
            when :type_errors then self.type_errors = mode
            when :logstruct_errors then self.logstruct_errors = mode
            when :standard_errors then self.standard_errors = mode
            else
              raise ArgumentError, "Unknown error type: #{error_type}"
            end
          end
        end
      end
    end
  end
end
