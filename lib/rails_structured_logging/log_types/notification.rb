# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative 'base'

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Notification log data struct
    class NotificationLogData < BaseLogData
      extend T::Sig

      const :notification_type, Symbol
      const :error_class, T.nilable(String)
      const :error_message, T.nilable(String)
      const :recipients, T.nilable(String)
      const :mailer_class, T.nilable(String)
      const :mailer_action, T.nilable(String)
      const :message_id, T.nilable(String)
      const :user_id, T.nilable(Integer)
      const :resource_type, T.nilable(String)
      const :resource_id, T.nilable(T.any(Integer, String))
    end

    # Helper method to create a notification log data object for email errors
    sig { params(error: StandardError, mailer: T.untyped).returns(NotificationLogData) }
    def self.create_email_notification_log_data(error, mailer)
      # Extract error class name safely
      error_class_name = T.unsafe(error.class).name

      # Create notification data with safely accessed properties
      NotificationLogData.new(
        src: :mailer,
        evt: Constants::EVT_NOTIFICATION,
        error_class: error_class_name,
        error_message: error.message,
        recipients: extract_recipients(error),
        notification_type: :email_delivery_error,
        mailer_class: T.unsafe(mailer).class.name,
        mailer_action: T.unsafe(mailer).respond_to?(:action_name) ? T.unsafe(mailer).action_name : nil,
        message_id: T.unsafe(mailer).respond_to?(:message) ? T.unsafe(mailer).message&.message_id : nil
      )
    end

    # Helper method to create a general notification log data object
    sig do
      params(
        notification_type: Symbol,
        message: String,
        source: Symbol,
        additional_data: T::Hash[T.any(Symbol, String), T.untyped]
      ).returns(NotificationLogData)
    end
    def self.create_notification_log_data(notification_type, message, source = :app, additional_data = {})
      # Create notification data
      NotificationLogData.new(
        src: source,
        evt: Constants::EVT_NOTIFICATION,
        msg: message,
        notification_type: notification_type,
        additional_data: additional_data
      )
    end

    # Helper method to extract recipients from an error
    sig { params(error: StandardError).returns(String) }
    def self.extract_recipients(error)
      # Extract recipient info if available
      if error.respond_to?(:recipients) && T.unsafe(error).recipients.present?
        T.unsafe(error).recipients.join(', ')
      else
        'unknown'
      end
    end
  end
end
