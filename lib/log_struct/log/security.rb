# typed: strict
# frozen_string_literal: true

require_relative "interfaces/log_interface"
require_relative "interfaces/request_interface"
require_relative "interfaces/msg_interface"
require_relative "interfaces/data_interface"
require_relative "shared/data_merging"
require_relative "shared/merge_data_fields"
require_relative "../enums/source"
require_relative "../enums/log_event"
require_relative "../log_level"
require_relative "../log_security_event"
require_relative "../log_keys"

module LogStruct
  module Log
    # Security log entry for structured logging of security-related events
    class Security < T::Struct
      extend T::Sig

      include CommonInterface
      include RequestInterface
      include MessageInterface
      include DataInterface
      include SerializeCommon
      include AddRequestFields
      include MergeDataFields

      SecurityLogEvent = T.type_alias {
        T.any(
          LogEvent::IPSpoof,
          LogEvent::CSRFViolation,
          LogEvent::BlockedHost
        )
      }

      # Common fields
      const :source, Source, default: T.let(Source::Security, Source)
      const :event, SecurityLogEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, LogLevel, default: T.let(LogLevel::Error, LogLevel)

      # Security-specific fields
      const :message, T.nilable(String), default: nil
      const :blocked_host, T.nilable(String), default: nil
      const :blocked_hosts, T.nilable(T::Array[String]), default: nil
      const :client_ip, T.nilable(String), default: nil
      const :x_forwarded_for, T.nilable(String), default: nil

      # Additional data (merged into hash)
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Common request fields
      const :path, T.nilable(String), default: nil
      const :http_method, T.nilable(String), default: nil, name: "method"
      const :source_ip, T.nilable(String), default: nil
      const :user_agent, T.nilable(String), default: nil
      const :referer, T.nilable(String), default: nil
      const :request_id, T.nilable(String), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = serialize_common
        add_request_fields(hash)
        merge_data_fields(hash)

        # Add security-specific fields
        hash[LogKeys::MSG] = message if message
        hash[LogKeys::BLOCKED_HOST] = blocked_host if blocked_host
        hash[LogKeys::BLOCKED_HOSTS] = blocked_hosts if blocked_hosts
        hash[LogKeys::CLIENT_IP] = client_ip if client_ip
        hash[LogKeys::X_FORWARDED_FOR] = x_forwarded_for if x_forwarded_for

        hash
      end
    end
  end
end
