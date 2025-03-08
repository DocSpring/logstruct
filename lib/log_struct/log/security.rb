# typed: strict
# frozen_string_literal: true

require_relative "interfaces/common_fields"
require_relative "interfaces/data_field"
require_relative "interfaces/message_field"
require_relative "interfaces/request_fields"
require_relative "shared/add_request_fields"
require_relative "shared/merge_data_fields"
require_relative "shared/serialize_common"
require_relative "../enums/event"
require_relative "../enums/level"
require_relative "../enums/source"
require_relative "../log_keys"

module LogStruct
  module Log
    # Security log entry for structured logging of security-related events
    class Security < T::Struct
      extend T::Sig

      include Interfaces::CommonFields
      include Interfaces::DataField
      include Interfaces::MessageField
      include Interfaces::RequestFields
      include SerializeCommon
      include AddRequestFields
      include MergeDataFields

      SecurityEvent = T.type_alias {
        T.any(
          Event::IPSpoof,
          Event::CSRFViolation,
          Event::BlockedHost
        )
      }

      # Common fields
      const :source, Source::Security, default: T.let(Source::Security, Source::Security)
      const :event, SecurityEvent
      const :timestamp, Time, factory: -> { Time.now }
      const :level, Level, default: T.let(Level::Error, Level)

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
      sig { override.params(strict: T::Boolean).returns(T::Hash[Symbol, T.untyped]) }
      def serialize(strict = true)
        hash = serialize_common(strict)
        add_request_fields(hash)
        merge_data_fields(hash)

        # Add security-specific fields
        hash[LOG_KEYS.fetch(:message)] = message if message
        hash[LOG_KEYS.fetch(:blocked_host)] = blocked_host if blocked_host
        hash[LOG_KEYS.fetch(:blocked_hosts)] = blocked_hosts if blocked_hosts
        hash[LOG_KEYS.fetch(:client_ip)] = client_ip if client_ip
        hash[LOG_KEYS.fetch(:x_forwarded_for)] = x_forwarded_for if x_forwarded_for

        hash
      end
    end
  end
end
