# typed: strict
# frozen_string_literal: true

module LogStruct
  module CustomHandlers
    extend T::Sig

    # Type for exception reporting handlers
    ExceptionReporter = T.type_alias do
      T.proc.params(error: StandardError, context: T::Hash[Symbol, T.untyped]).void
    end

    # Type for string scrubbing handlers
    StringScrubber = T.type_alias do
      T.proc.params(str: String).returns(String)
    end
  end
end
