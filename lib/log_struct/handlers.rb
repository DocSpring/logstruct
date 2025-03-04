# typed: strict
# frozen_string_literal: true

module LogStruct
  # Module for custom handlers used throughout the library
  module Handlers
    # Type for exception reporting handlers
    ExceptionReporter = T.type_alias {
      T.proc.params(
        error: StandardError,
        context: T.nilable(T::Hash[Symbol, T.untyped]),
        source: Source
      ).void
    }

    # Type for string scrubbing handlers
    StringScrubber = T.type_alias { T.proc.params(string: String).returns(String) }
  end
end
