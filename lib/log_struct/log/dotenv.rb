# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/additional_data_field"
require_relative "shared/serialize_common"
require_relative "shared/merge_additional_data_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"

module LogStruct
  module Log
    # Structured log for dotenv-rails events (load/update/save/restore)
    class Dotenv < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::AdditionalDataField
      include SerializeCommon
      include MergeAdditionalDataFields

      DotenvEvent = T.type_alias {
        T.any(
          Event::Load,
          Event::Update,
          Event::Save,
          Event::Restore
        )
      }

      const :source, Source::Dotenv, default: T.let(Source::Dotenv, Source::Dotenv)
      const :event, DotenvEvent
      const :level, Level, default: T.let(Level::Info, Level)
      const :timestamp, Time, factory: -> { Time.now }

      const :file, T.nilable(String), default: nil
      const :vars, T.nilable(T::Array[String]), default: nil
      const :additional_data, T::Hash[Symbol, T.untyped], default: {}

      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        h = serialize_common(strict)
        merge_additional_data_fields(h)
        h[:file] = file if file
        h[:vars] = vars if vars
        h
      end
    end
  end
end
