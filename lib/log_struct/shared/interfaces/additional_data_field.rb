# typed: strict
# frozen_string_literal: true

# Moved from lib/log_struct/log/interfaces/additional_data_field.rb
module LogStruct
  module Log
    module Interfaces
      module AdditionalDataField
        extend T::Sig
        extend T::Helpers

        interface!

        requires_ancestor { T::Struct }

        sig { abstract.returns(T.nilable(T::Hash[T.any(String, Symbol), T.untyped])) }
        def additional_data
        end
      end
    end
  end
end
