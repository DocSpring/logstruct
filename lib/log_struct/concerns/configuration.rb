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
          yield(configuration)
        end

        sig { returns(LogStruct::Configuration) }
        def configuration
          LogStruct::Configuration.instance
        end

        # (Can't use alias_method since this module is extended into LogStruct)
        sig { returns(LogStruct::Configuration) }
        def config
          configuration
        end

        sig { returns(T::Boolean) }
        def enabled?
          configuration.enabled
        end
      end
    end
  end
end
