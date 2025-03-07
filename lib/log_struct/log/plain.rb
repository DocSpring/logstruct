# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "shared/serialize_common"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Plain log entry for structured logging
    class Plain < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::DataField
      include SerializeCommon
      include MergeDataFields

      PlainLogEvent = T.type_alias {
        LogEvent::Log
      }

      # Common fields
      const :source, Source, default: T.let(Source::App, Source)
      const :event, PlainLogEvent, default: T.let(LogEvent::Log, PlainLogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Plain log messages can be any type (String, Number, Array, Hash, etc.)
      # Developers might do something like Rails.logger.info(123) or Rails.logger.info(@variable)
      # when debugging, or gems might send all kinds of random stuff to the logger.
      # We don't want to crash with a type error in any of these cases.
      const :message, T.untyped # rubocop:disable Sorbet/ForbidUntypedStructProps

      # Allow people to submit additional data
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_data_fields(hash)
        hash[LOG_KEYS.fetch(:message)] = message
        hash
      end
    end
  end
end
