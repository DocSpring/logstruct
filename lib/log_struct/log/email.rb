# typed: strict
# frozen_string_literal: true

require_relative "log_entry_interface"
require_relative "../log_source"
require_relative "../log_event"

module LogStruct
  module Log
    # Email log entry for structured logging
    class Email < T::Struct
      include LogInterface

      # Common fields
      const :src, LogStruct::LogSource
      const :evt, LogStruct::LogEvent
      const :ts, Time, default: T.unsafe(-> { Time.now })
      const :msg, T.nilable(String), default: nil

      # Email-specific fields
      const :msg_id, T.nilable(String), default: nil
      const :mailer, T.nilable(String), default: nil
      const :action, T.nilable(String), default: nil
      const :to, T.nilable(String), default: nil
      const :cc, T.nilable(T.nilable(String)), default: nil
      const :bcc, T.nilable(T.nilable(String)), default: nil
      const :subject, T.nilable(String), default: nil

      # Convert the log entry to a hash for serialization
      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def serialize
        # Create a hash with all the struct's properties
        hash = {
          src: src.serialize,
          evt: evt.serialize,
          ts: ts.iso8601(3),
          msg: msg
        }

        # Add email-specific fields if they're present
        hash[:msg_id] = msg_id if msg_id
        hash[:mailer] = mailer if mailer
        hash[:action] = action if action
        hash[:to] = to if to
        hash[:cc] = cc if cc
        hash[:bcc] = bcc if bcc
        hash[:subject] = subject if subject

        hash
      end
    end
  end
end
