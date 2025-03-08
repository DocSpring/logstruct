# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/additional_data_field"
require_relative "interfaces/message_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_additional_data_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Exception log entry for Ruby exceptions with class, message, and backtrace
    class Error < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include Interfaces::MessageField
      include MergeAdditionalDataFields

      ErrorEvent = T.type_alias {
        Event::Error
      }

      # Common fields
      const :source, Source # Used by all sources, should not have a default.
      const :event, ErrorEvent, default: T.let(Event::Error, ErrorEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Error, Level)

      # Exception-specific fields
      const :err_class, T.class_of(StandardError)
      const :message, String
      const :backtrace, T.nilable(T::Array[String]), default: nil
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)

        # Add exception-specific fields
        hash[LOG_KEYS.fetch(:err_class)] = err_class.name
        hash[LOG_KEYS.fetch(:message)] = message
        if backtrace.is_a?(Array) && backtrace&.any?
          hash[LOG_KEYS.fetch(:backtrace)] = backtrace&.first(10)
        end

        hash
      end

      # Create an Error log from a Ruby StandardError
      sig {
        params(
          source: Source,
          ex: StandardError,
          additional_data: T::Hash[Symbol, T.untyped]
        ).returns(Log::Error)
      }
      def self.from_exception(source, ex, additional_data = {})
        new(
          source: source,
          message: ex.message,
          err_class: ex.class,
          backtrace: ex.backtrace,
          additional_data: additional_data
        )
      end
    end
  end
end
