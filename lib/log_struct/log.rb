# typed: strict
# frozen_string_literal: true

# Common Enums
require_relative "enums/source"
require_relative "enums/event"
require_relative "enums/level"
require_relative "log/interfaces/public_common_fields"
require_relative "log/shared/serialize_common_public"

# Log Structs
require_relative "log/carrierwave"
require_relative "log/action_mailer"
require_relative "log/active_storage"
require_relative "log/active_job"
require_relative "log/error"
require_relative "log/good_job"
require_relative "log/plain"
require_relative "log/request"
require_relative "log/security"
require_relative "log/shrine"
require_relative "log/sidekiq"
require_relative "log/sql"
require_relative "log/ahoy"
require_relative "log/active_model_serializers"
require_relative "log/dotenv"

module LogStruct
  # Type aliases for all possible log types
  # This should be updated whenever a new log type is added
  # (Can't use sealed! unless we want to put everything in one giant file.)
  LogClassType = T.type_alias do
    T.any(
      T.class_of(LogStruct::Log::CarrierWave),
      T.class_of(LogStruct::Log::ActionMailer),
      T.class_of(LogStruct::Log::ActiveStorage),
      T.class_of(LogStruct::Log::ActiveJob),
      T.class_of(LogStruct::Log::Error),
      T.class_of(LogStruct::Log::GoodJob),
      T.class_of(LogStruct::Log::Plain),
      T.class_of(LogStruct::Log::Request),
      T.class_of(LogStruct::Log::Security),
      T.class_of(LogStruct::Log::Shrine),
      T.class_of(LogStruct::Log::Sidekiq),
      T.class_of(LogStruct::Log::SQL),
      T.class_of(LogStruct::Log::Ahoy),
      T.class_of(LogStruct::Log::ActiveModelSerializers),
      T.class_of(LogStruct::Log::Dotenv)
    )
  end
end
