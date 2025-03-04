# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Email log entry for structured logging
    class Email < T::Struct
      include LogInterface
      include LogSerialization

      # Common fields
      const :source, LogSource, name: :src, default: T.let(LogSource::Mailer, LogSource)
      const :event, LogEvent, name: :evt
      const :timestamp, Time, name: :ts, factory: -> { Time.now }
      const :level, LogLevel, name: :lvl, default: T.let(LogLevel::Info, LogLevel)

      # Email-specific fields
      const :to, T.nilable(T.any(String, T::Array[String])), default: nil
      const :from, T.nilable(String), default: nil
      const :subject, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

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
