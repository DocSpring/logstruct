# typed: strict
# frozen_string_literal: true

require_relative "../configuration"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Configuration
      module ClassMethods
        extend T::Sig

        sig { params(block: T.proc.params(config: Untyped::Configuration).void).void }
        def configure(&block)
          yield(LogStruct::Untyped::Configuration.new(configuration))
        end

        sig { params(block: T.proc.params(config: LogStruct::Configuration).void).void }
        def configure_typed(&block)
          yield(configuration)
        end

        sig { returns(LogStruct::Configuration) }
        def configuration
          LogStruct::Configuration.configuration
        end

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
