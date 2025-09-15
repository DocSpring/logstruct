# typed: strict
# frozen_string_literal: true

require_relative "../../enums/source"
require_relative "../../enums/event"
require_relative "../../enums/level"

module LogStruct
  module Log
    module Interfaces
      module CommonFields
        extend T::Sig
        extend T::Helpers

        interface!

        sig { abstract.returns(Source) }
        def source
        end

        sig { abstract.returns(Event) }
        def event
        end

        sig { abstract.returns(Level) }
        def level
        end

        sig { abstract.returns(Time) }
        def timestamp
        end

        sig { abstract.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
        def serialize(strict = true)
        end
      end
    end
  end
end
