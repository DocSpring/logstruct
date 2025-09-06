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
    # Ahoy analytics log entry for structured logging
    class Ahoy < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      # Events are generic logs for tracking
      AhoyEvent = T.type_alias {
        Event::Log
      }

      # Common fields
      const :source, Source, default: T.let(Source::App, Source)
      const :event, AhoyEvent, default: T.let(Event::Log, AhoyEvent)
      const :level, Level, default: T.let(Level::Info, Level)
      const :timestamp, Time, factory: -> { Time.now }

      # Ahoy specifics
      const :message, String, default: "ahoy.track"
      const :ahoy_event, T.nilable(String), default: nil
      const :properties, T.nilable(T::Hash[Symbol, T.untyped]), default: nil

      # Extra data
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)
        hash[LOG_KEYS.fetch(:message)] = message
        hash[:ahoy_event] = ahoy_event if ahoy_event
        hash[:properties] = properties if properties
        hash
      end
    end
  end
end
