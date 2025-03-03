# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "request_interface"
require_relative "request_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Request log entry for structured logging
    class Request < T::Struct
      include LogInterface
      include LogSerialization
      include RequestInterface
      include RequestSerialization

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Rails, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :lvl, LogLevel, default: T.let(LogLevel::Info, LogLevel)
      const :msg, T.nilable(String), default: nil

      # Request-specific fields
      # NOTE: `method` is a reserved word, so we use a `http_method`
      # prop while setting `method` in the log JSON
      const :http_method, T.nilable(String), default: nil
      const :path, T.nilable(String), default: nil
      const :format, T.nilable(String), default: nil
      const :controller, T.nilable(String), default: nil
      const :action, T.nilable(String), default: nil
      const :status, T.nilable(Integer), default: nil
      const :duration, T.nilable(Float), default: nil
      const :view, T.nilable(Float), default: nil
      const :db, T.nilable(Float), default: nil
      const :params, T.nilable(T::Hash[String, T.untyped]), default: nil
      const :source_ip, T.nilable(String), default: nil
      const :user_agent, T.nilable(String), default: nil
      const :referer, T.nilable(String), default: nil
      const :request_id, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add message if present
        hash[:msg] = msg if msg

        # Add request-specific fields
        hash.merge!(serialize_request_fields)

        # Add other request-specific fields
        hash[:format] = format if format
        hash[:controller] = controller if controller
        hash[:action] = action if action
        hash[:status] = status if status
        hash[:duration] = duration if duration
        hash[:view] = view if view
        hash[:db] = db if db
        hash[:params] = params if params

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
