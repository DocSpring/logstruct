# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/request_fields"
require_relative "shared/serialize_common"
require_relative "shared/add_request_fields"
require_relative "../enums/source"
require_relative "../enums/event"
require_relative "../enums/level"
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

      RequestEvent = T.type_alias {
        Event::Request
      }

      # Common fields
      const :source, Source::Rails, default: T.let(Source::Rails, Source::Rails)
      const :event, RequestEvent, default: T.let(Event::Request, RequestEvent)
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Info, Level)

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
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        add_request_fields(hash)
        hash[LOG_KEYS.fetch(:http_method)] = http_method if http_method
        hash[LOG_KEYS.fetch(:path)] = path if path
        hash[LOG_KEYS.fetch(:format)] = format if format
        hash[LOG_KEYS.fetch(:controller)] = controller if controller
        hash[LOG_KEYS.fetch(:action)] = action if action
        hash[LOG_KEYS.fetch(:status)] = status if status
        hash[LOG_KEYS.fetch(:duration)] = duration if duration
        hash[LOG_KEYS.fetch(:view)] = view if view
        hash[LOG_KEYS.fetch(:db)] = db if db
        hash[LOG_KEYS.fetch(:params)] = params if params
        hash[LOG_KEYS.fetch(:source_ip)] = source_ip if source_ip
        hash[LOG_KEYS.fetch(:user_agent)] = user_agent if user_agent
        hash[LOG_KEYS.fetch(:referer)] = referer if referer
        hash[LOG_KEYS.fetch(:request_id)] = request_id if request_id

        hash
      end
    end
  end
end
