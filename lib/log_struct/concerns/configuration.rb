# typed: strict
# frozen_string_literal: true

require_relative "../configuration"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      module ClassMethods
        extend T::Sig

        sig { params(block: T.proc.params(config: LogStruct::Configuration).void).void }
        def configure(&block)
          yield(config)
        end

        sig { returns(LogStruct::Configuration) }
        def config
          LogStruct::Configuration.instance
        end

        # (Can't use alias_method since this module is extended into LogStruct)
        sig { returns(LogStruct::Configuration) }
        def configuration
          config
        end

        # Setter method to replace the configuration (for testing purposes)
        sig { params(config: LogStruct::Configuration).void }
        def configuration=(config)
          LogStruct::Configuration.set_instance(config)
        end

        sig { returns(T::Boolean) }
        def enabled?
          config.enabled
        end

        sig { returns(T::Boolean) }
        def is_local?
          config.local_environments.include?(::Rails.env.to_sym)
        end

        sig { returns(T::Boolean) }
        def is_production?
          !is_local?
        end
      end
    end
  end
end
