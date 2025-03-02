# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Email log entry for structured logging
    class Email < T::Struct
      include LogInterface

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Mailer, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :msg, T.nilable(String), default: nil

      # Email-specific fields
      const :to, T.nilable(T.any(String, T::Array[String])), default: nil
      const :from, T.nilable(String), default: nil
      const :subject, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }

        # Add email-specific fields if they're present
        hash[:to] = to if to
        hash[:from] = from if from
        hash[:subject] = subject if subject

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
