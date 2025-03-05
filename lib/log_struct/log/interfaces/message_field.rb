# typed: strict
# frozen_string_literal: true

module LogStruct
  module Log
    module Interfaces
      # Common interface for logs that include a message field
      module MessageField
        extend T::Sig
        extend T::Helpers

        interface!

        # Message field
        sig { abstract.returns(T.nilable(String)) }
        def message; end
      end
    end
  end
end
