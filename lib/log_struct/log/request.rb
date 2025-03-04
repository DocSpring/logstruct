# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/request_fields"
require_relative "shared/serialize_common"
require_relative "shared/add_request_fields"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../enums/log_level"
require_relative "../log_keys"

module LogStruct
  module Log
    # Request log entry for structured logging
    class Request < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::RequestFields
      include SerializeCommon
      include AddRequestFields

      RequestLogEvent = T.type_alias {
        LogEvent::Request
      }

      # Common fields
      const :source, Source, default: T.let(Source::Request, Source)
      const :event, RequestLogEvent, default: T.let(LogEvent::Request, RequestLogEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Info, LogLevel)

      # Request-specific fields
      # NOTE: `method` is a reserved word, so we use `http_method`
      # prop while setting `method` in the serialized output
      const :http_method, T.nilable(String), default: nil
      const :path, T.nilable(String), default: nil
      const :format, T.nilable(String), default: nil
      const :controller, T.nilable(String), default: nil
      const :action, T.nilable(String), default: nil
      const :status, T.nilable(Integer), default: nil
      const :duration, T.nilable(Float), default: nil
      const :view, T.nilable(Float), default: nil
      const :db, T.nilable(Float), default: nil
      const :params, T.nilable(T::Hash[Symbol, T.untyped]), default: nil
      const :source_ip, T.nilable(String), default: nil
      const :user_agent, T.nilable(String), default: nil
      const :referer, T.nilable(String), default: nil
      const :request_id, T.nilable(String), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        add_request_fields(hash)
        hash[LogKeys::METHOD] = http_method if http_method
        hash[LogKeys::PATH] = path if path
        hash[LogKeys::FORMAT] = format if format
        hash[LogKeys::CONTROLLER] = controller if controller
        hash[LogKeys::ACTION] = action if action
        hash[LogKeys::STATUS] = status if status
        hash[LogKeys::DURATION] = duration if duration
        hash[LogKeys::VIEW] = view if view
        hash[LogKeys::DB] = db if db
        hash[LogKeys::PARAMS] = params if params
        hash[LogKeys::SOURCE_IP] = source_ip if source_ip
        hash[LogKeys::USER_AGENT] = user_agent if user_agent
        hash[LogKeys::REFERER] = referer if referer
        hash[LogKeys::REQUEST_ID] = request_id if request_id

        hash
      end
    end
  end
end
