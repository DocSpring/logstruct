# frozen_string_literal: true

module RailsStructuredLogging
  module ActionMailer
    # Handles structured logging for ActionMailer
    module Logger
      # Build base log data common to all logging methods
      def self.build_base_log_data(mailer, event_type)
        log_data = {
          src: 'mailer',
          evt: event_type,
          ts: Time.current.iso8601(3),
          message_id: mailer.respond_to?(:message) ? mailer.message&.message_id : nil,
          mailer_class: mailer.class.name,
          mailer_action: mailer.respond_to?(:action_name) ? mailer.action_name : nil,
        }

        MetadataCollection.add_message_metadata(mailer, log_data)
        MetadataCollection.add_context_metadata(mailer, log_data)

        log_data
      end

      # Log structured error information
      def self.log_structured_error(mailer, error, message)
        log_data = build_base_log_data(mailer, 'email_error')
        log_data[:error_class] = error.class.name
        log_data[:error_message] = error.message
        log_data[:msg] = message
        log_to_rails(log_data, :error)
      end

      # Log to Rails logger with structured data
      def self.log_to_rails(message, level = :info)
        Rails.logger.public_send(level, message)
      end
    end
  end
end
