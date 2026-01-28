# typed: strict
# frozen_string_literal: true

require_relative "../../enums/source"
require_relative "../../enums/event"
require_relative "../../enums/level"
require_relative "common_field_base"

module LogStruct
  module Log
    module Interfaces
      module CommonFields
        extend T::Sig
        extend T::Helpers

        interface!

        include CommonFieldBase

        sig { abstract.returns(Source) }
        def source
        end

        sig { abstract.returns(Event) }
        def event
        end
      end
    end
  end
end
