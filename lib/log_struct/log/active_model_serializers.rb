# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/additional_data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_additional_data_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"
require_relative "../log_keys"

module LogStruct
  module Log
    # ActiveModelSerializers render log entry for structured logging
    class ActiveModelSerializers < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      AMSEvent = T.type_alias { Event::Generate }

      # Common fields
      const :source, Source::Rails, default: T.let(Source::Rails, Source::Rails)
      const :event, AMSEvent, default: T.let(Event::Generate, AMSEvent)
      const :level, Level, default: T.let(Level::Info, Level)
      const :timestamp, Time, factory: -> { Time.now }

      # AMS specifics
      const :message, String, default: "ams.render"
      const :serializer, T.nilable(String), default: nil
      const :adapter, T.nilable(String), default: nil
      const :resource_class, T.nilable(String), default: nil
      const :duration_ms, T.nilable(Float), default: nil

      # Extra data
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)
        hash[LOG_KEYS.fetch(:message)] = message
        hash[:serializer] = serializer if serializer
        hash[:adapter] = adapter if adapter
        hash[:resource_class] = resource_class if resource_class
        hash[:duration_ms] = duration_ms if duration_ms
        hash
      end
    end
  end
end
