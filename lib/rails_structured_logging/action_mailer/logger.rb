# frozen_string_literal: true
# typed: true

require_relative '../sorbet'

module RailsStructuredLogging
  module ActionMailer
    # Handles structured logging for ActionMailer
    module Logger
      include RailsStructuredLogging::TypedSig
      extend T::Sig

      # Build base log data common to all logging methods
      sig { params(mailer: T.untyped, event_type: String).returns(T::Hash[Symbol, T.nilable(T.any(String, Integer, Float, T::Boolean))]) }
      def self.build_base_log_data(mailer, event_type)
        log_data = {
          src: 'mailer',
          evt: event_type,
          ts: Time.current.iso8601(3),
          message_id: extract_message_id(mailer),
          mailer_class: mailer.class.name,
          mailer_action: mailer.respond_to?(:action_name) ? mailer.action_name : nil,
        }

        MetadataCollection.add_message_metadata(mailer, log_data)
        MetadataCollection.add_context_metadata(mailer, log_data)

        log_data
      end

      # Extract message_id safely from mailer
      sig { params(mailer: T.untyped).returns(T.nilable(String)) }
      def self.extract_message_id(mailer)
        return nil unless mailer.respond_to?(:message)

        message = mailer.message
        if message.respond_to?(:message_id)
          message.message_id
        else
          nil
        end
      end

      # Log structured error information
      sig { params(mailer: T.untyped, error: StandardError, message: String).void }
      def self.log_structured_error(mailer, error, message)
        log_data = build_base_log_data(mailer, 'email_error')
        log_data[:error_class] = T.unsafe(error.class).name
        log_data[:error_message] = error.message
        log_data[:msg] = message
        log_to_rails(log_data, :error)
      end

      # Log to Rails logger with structured data
      sig { params(message: T.any(String, T::Hash[T.untyped, T.untyped]), level: Symbol).void }
      def self.log_to_rails(message, level = :info)
        Rails.logger.public_send(level, message)
      end
    end
  end
end
