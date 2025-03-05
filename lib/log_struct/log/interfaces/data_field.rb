# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    module Interfaces
      # Common interface for logs that include a data field
      module DataField
        extend T::Sig
        extend T::Helpers

        interface!

        # Data field for additional context
        sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
        def data; end
      end
    end
  end
end
