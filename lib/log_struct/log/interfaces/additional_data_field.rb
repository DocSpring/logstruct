# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    module Interfaces
      # Common interface for logs that include an additional_data field
      module AdditionalDataField
        extend T::Sig
        extend T::Helpers

        interface!

        # Additional data field for extra context
        sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
        def additional_data; end
      end
    end
  end
end
