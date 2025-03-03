# typed: strict
# frozen_string_literal: true

require_relative "log_interface"
require_relative "log_serialization"
require_relative "request_interface"
require_relative "request_serialization"
require_relative "../log_source"
require_relative "../log_event"
require_relative "../log_level"
require_relative "../log_security_event"

module LogStruct
  module Log
    # Security log entry for structured logging of security-related events
    class Security < T::Struct
      include LogInterface
      include LogSerialization
      include RequestInterface
      include RequestSerialization

      # Common fields
      const :src, LogSource, default: T.let(LogSource::Rails, LogSource)
      const :evt, LogEvent, default: T.let(LogEvent::Security, LogEvent)
      const :ts, Time, factory: -> { Time.now }
      const :lvl, LogLevel, default: T.let(LogLevel::Warn, LogLevel)

      # Security-specific fields
      const :sec_evt, LogSecurityEvent
      const :msg, T.nilable(String), default: nil

      # Request-related fields
      const :path, T.nilable(String), default: nil
      const :http_method, T.nilable(String), default: nil
      const :source_ip, T.nilable(String), default: nil
      const :user_agent, T.nilable(String), default: nil
      const :referer, T.nilable(String), default: nil
      const :request_id, T.nilable(String), default: nil

      # Additional security-specific fields
      const :blocked_host, T.nilable(String), default: nil
      const :blocked_hosts, T.nilable(T::Array[String]), default: nil
      const :client_ip, T.nilable(String), default: nil
      const :x_forwarded_for, T.nilable(String), default: nil
      const :data, T::Hash[Symbol, T.untyped], default: {}

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        hash = common_serialize

        # Add security-specific fields
        hash[:sec_evt] = sec_evt.serialize
        hash[:msg] = msg if msg

        # Add request-related fields
        hash.merge!(serialize_request_fields)

        # Add additional security-specific fields
        hash[:blocked_host] = blocked_host if blocked_host
        hash[:blocked_hosts] = blocked_hosts if blocked_hosts
        hash[:client_ip] = client_ip if client_ip
        hash[:x_forwarded_for] = x_forwarded_for if x_forwarded_for

        # Merge any additional data
        hash.merge!(data) if data.any?

        hash
      end
    end
  end
end
