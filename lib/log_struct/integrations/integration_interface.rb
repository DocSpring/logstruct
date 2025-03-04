# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    # Interface that all integrations must implement
    # This ensures consistent behavior across all integration modules
    module IntegrationInterface
      extend T::Sig
      extend T::Helpers

      # This is an interface that should be implemented by all integration modules
      interface!

      # All integrations must implement this method to set up their functionality
      sig { abstract.params(config: LogStruct::Configuration).void }
      def setup(config); end
    end
  end
end
