# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_interface"
require_relative "interfaces/data_interface"
require_relative "interfaces/message_interface"
require_relative "shared/serialize_common"
require_relative "shared/merge_data_fields"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Exception log entry for Ruby exceptions with class, message, and backtrace
    class Exception < T::Struct
      extend T::Sig

      include CommonInterface
      include DataInterface
      include MessageInterface
      include MergeDataFields

      ExceptionLogEvent = T.type_alias {
        LogEvent::Error
      }

      # Common fields
      const :source, Source # Used by all sources, should not have a default.
      const :event, ExceptionLogEvent, default: T.let(LogEvent::Error, ExceptionLogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Error, LogLevel)

      # Exception-specific fields
      const :message, String
      const :err_class, T.class_of(StandardError)
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        merge_data_fields(hash)

        # Add exception-specific fields
        hash[LogKeys::ERR_CLASS] = err_class.name
        hash[LogKeys::MSG] = message
        hash[LogKeys::BACKTRACE] = backtrace if backtrace

        hash
      end

      # Create an Exception log from a Ruby exception
      sig {
        params(
          source: Source,
          ex: StandardError,
          data: T::Hash[Symbol, T.untyped]
        ).returns(Log::Exception)
      }
      def self.from_exception(source, ex, data = {})
        new(
          source: source,
          message: ex.message,
          err_class: ex.class,
          backtrace: ex.backtrace,
          data: data
        )
      end
    end
  end
end
