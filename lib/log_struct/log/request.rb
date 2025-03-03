# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "request_interface"
require_relative "msg_interface"
require_relative "data_interface"
require_relative "merge_data"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"

module LogStruct
  module Log
    # Request log entry for structured logging
    class Request < T::Struct
      include LogInterface
      include RequestInterface
      include MsgInterface
      include DataInterface
      include MergeData

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Rails, LogSource)
      const :evt, LogEvent
      const :ts, Time, factory: -> { Time.now }
      const :lvl, LogLevel, default: T.let(LogLevel::Info, LogLevel)
      const :msg, T.nilable(String), default: nil

      # Request-specific fields
      # NOTE: `method` is a reserved word, so we use `http_method`
      # prop while setting `method` in the serialized output
      const :http_method, T.nilable(String), default: nil, name: "method"
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
    end
  end
end
