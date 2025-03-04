# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class Untyped
      class Integrations
        sig { params(typed: Configuration::Integrations).void }
        def initialize(typed)
          @typed = typed
        end

        sig { params(enabled: T::Boolean).void }
        def lograge_enabled=(enabled)
          @typed.lograge_enabled = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def emails_enabled=(enabled)
          @typed.emails_enabled = enabled
        end

        sig { params(settings: T::Hash[Symbol, T::Boolean]).void }
        def configure(settings)
          settings.each do |integration, enabled|
            case integration
            when :lograge then self.lograge_enabled = enabled
            when :emails then self.emails_enabled = enabled
            else
              raise ArgumentError, "Unknown integration: #{integration}"
            end
          end
        end
      end
    end
  end
end
