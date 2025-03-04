# typed: strict
# frozen_string_literal: true

require_relative "../../enums/source"
require_relative "../../enums/log_event"
require_relative "../../enums/log_level"

module LogStruct
  module Log
    module Interfaces
      # Common interface that all log entry types must implement
      module CommonFields
        extend T::Sig
        extend T::Helpers

        interface!

        # The source of the log entry (JSON property: src)
        sig { abstract.returns(Source) }
        def source; end

        # The event type of the log entry (JSON property: evt)
        sig { abstract.returns(LogEvent) }
        def event; end

        # The timestamp of the log entry (JSON property: ts)
        sig { abstract.returns(Time) }
        def timestamp; end

        # The log level of the log entry (JSON property: lvl)
        sig { abstract.returns(LogLevel) }
        def level; end

        # All logs must define a custom serialize method
        sig { abstract.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
        def serialize(strict = true); end
      end
    end
  end
end
