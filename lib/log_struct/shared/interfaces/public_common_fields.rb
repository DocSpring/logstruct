# typed: strict
# frozen_string_literal: true

require_relative "../../enums/level"
require_relative "common_field_base"

module LogStruct
  module Log
    module Interfaces
      module PublicCommonFields
        extend T::Sig
        extend T::Helpers

        interface!

        include CommonFieldBase
      end
    end
  end
end
