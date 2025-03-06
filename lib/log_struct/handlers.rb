# typed: strict
# frozen_string_literal: true

module LogStruct
  # Module for custom handlers used throughout the library
  module Handlers
    # Type for Lograge custom options
    LogrageCustomOptions = T.type_alias {
      T.proc.params(
        event: ActiveSupport::Notifications::Event,
        options: T::Hash[Symbol, T.untyped]
      ).returns(T.untyped)
    }

    # Type for error reporting handlers
    ErrorReporter = T.type_alias {
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
