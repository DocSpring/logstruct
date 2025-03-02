# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Exception log entry for Ruby exceptions with class, message, and backtrace
    class Exception < T::Struct
      include LogInterface
      include LogSerialization

      # Common fields
      const :src, LogSource # Used by all sources, should not have a default.
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }

      # Exception-specific fields
      const :err_class, T.class_of(StandardError)
      const :msg, String
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add exception-specific fields
        hash[:err_class] = err_class.name
        hash[:msg] = msg
        hash[:backtrace] = backtrace if backtrace

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end

      # Create an Exception log from a Ruby exception
      sig { params(src: LogSource, evt: LogEvent, ex: StandardError, data: T::Hash[Symbol, T.untyped]).returns(Exception) }
      def self.from_exception(src, evt, ex, data = {})
        new(
          src: src,
          evt: evt,
          err_class: ex.class,
          msg: ex.message,
          backtrace: ex.backtrace,
          data: data
        )
      end
    end
  end
end
