# typed: strict
# frozen_string_literal: true

module LogStruct
  module Untyped
    class Configuration
      class Integrations
        extend T::Sig

        sig { params(typed: LogStruct::Configuration::Integrations).void }
        def initialize(typed)
          @typed = T.let(typed, LogStruct::Configuration::Integrations)
        end

        sig { params(enabled: T::Boolean).void }
        def enable_lograge=(enabled)
          @typed.enable_lograge = enabled
        end

        sig { params(options: T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped)).void }
        def lograge_custom_options=(options)
          @typed.lograge_custom_options = options
        end

        sig { params(enabled: T::Boolean).void }
        def enable_actionmailer=(enabled)
          @typed.enable_actionmailer = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_host_authorization=(enabled)
          @typed.enable_host_authorization = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_activejob=(enabled)
          @typed.enable_activejob = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_rack_error_handler=(enabled)
          @typed.enable_rack_error_handler = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_sidekiq=(enabled)
          @typed.enable_sidekiq = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_shrine=(enabled)
          @typed.enable_shrine = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_active_storage=(enabled)
          @typed.enable_active_storage = enabled
        end

        sig { params(enabled: T::Boolean).void }
        def enable_carrierwave=(enabled)
          @typed.enable_carrierwave = enabled
        end

        sig { params(settings: T::Hash[Symbol, T.untyped]).void }
        def configure(settings)
          settings.each do |key, value|
            case key
            when :lograge then self.enable_lograge = T.cast(value, T::Boolean)
            when :lograge_custom_options then self.lograge_custom_options = T.cast(value, T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))
            when :actionmailer then self.enable_actionmailer = T.cast(value, T::Boolean)
            when :host_authorization then self.enable_host_authorization = T.cast(value, T::Boolean)
            when :activejob then self.enable_activejob = T.cast(value, T::Boolean)
            when :rack_error_handler then self.enable_rack_error_handler = T.cast(value, T::Boolean)
            when :sidekiq then self.enable_sidekiq = T.cast(value, T::Boolean)
            when :shrine then self.enable_shrine = T.cast(value, T::Boolean)
            when :active_storage then self.enable_active_storage = T.cast(value, T::Boolean)
            when :carrierwave then self.enable_carrierwave = T.cast(value, T::Boolean)
            else
              raise ArgumentError, "Unknown integration setting: #{key}"
            end
          end
        end
      end
    end
  end
end
