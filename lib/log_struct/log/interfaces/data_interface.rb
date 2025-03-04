# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    # Common interface for logs that include a data field
    module DataInterface
      extend T::Helpers

      interface!

      # Data field for additional context
      sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
      def data; end
    end
  end
end
