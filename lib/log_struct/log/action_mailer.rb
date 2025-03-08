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
    # Email log entry for structured logging
    class ActionMailer < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      ActionMailerEvent = T.type_alias {
        T.any(Event::Delivery, Event::Delivered)
      }

      # Common fields
      const :source, Source::Mailer, default: T.let(Source::Mailer, Source::Mailer)
      const :event, ActionMailerEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

      # Email-specific fields
      const :to, T.nilable(T.any(String, T::Array[String])), default: nil
      const :from, T.nilable(String), default: nil
      const :subject, T.nilable(String), default: nil
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        merge_additional_data_fields(hash)

        # Add email-specific fields if they're present
        hash[LOG_KEYS.fetch(:to)] = to if to
        hash[LOG_KEYS.fetch(:from)] = from if from
        hash[LOG_KEYS.fetch(:subject)] = subject if subject

        hash
      end
    end
  end
end
