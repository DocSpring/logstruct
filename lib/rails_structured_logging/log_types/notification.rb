# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "base"
require_relative "../enums"

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Notification log data class
    class NotificationLogData < BaseLogData
      extend T::Sig

      sig { returns(Symbol) }
      attr_reader :notification_type

      sig { returns(T.nilable(String)) }
      attr_reader :error_class

      sig { returns(T.nilable(String)) }
      attr_reader :error_message

      sig { returns(T.nilable(String)) }
      attr_reader :recipients

      sig { returns(T.nilable(Integer)) }
      attr_reader :user_id

      sig { returns(T.nilable(String)) }
      attr_reader :resource_type

      sig { returns(T.nilable(T.any(Integer, String))) }
      attr_reader :resource_id

      # Initialize with all fields
      sig do
        params(
          src: Symbol,
          evt: Symbol,
          notification_type: Symbol,
          ts: T.nilable(Time),
          msg: T.nilable(String),
          error_class: T.nilable(String),
          error_message: T.nilable(String),
          recipients: T.nilable(String),
          user_id: T.nilable(Integer),
          resource_type: T.nilable(String),
          resource_id: T.nilable(T.any(Integer, String))
        ).void
      end
      def initialize(src:, evt:, notification_type:, ts: nil, msg: nil, error_class: nil,
        error_message: nil, recipients: nil, user_id: nil,
        resource_type: nil, resource_id: nil)
        super(src: src, evt: evt, ts: ts, msg: msg)
        @notification_type = notification_type
        @error_class = error_class
        @error_message = error_message
        @recipients = recipients
        @user_id = user_id
        @resource_type = resource_type
        @resource_id = resource_id
      end

      # Convert to hash for logging
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        super.merge({
          notification_type: @notification_type,
          error_class: @error_class,
          error_message: @error_message,
          recipients: @recipients,
          user_id: @user_id,
          resource_type: @resource_type,
          resource_id: @resource_id
        }.compact)
      end
    end

    # Helper method to create a notification log data object for email errors
    sig { params(error: StandardError, mailer: T.untyped).returns(NotificationLogData) }
    def self.create_email_notification_log_data(error, _mailer)
      # Extract error class name safely
      error_class_name = T.unsafe(error.class).name

      # Create notification data with safely accessed properties
      NotificationLogData.new(
        src: :mailer,
        evt: :notification,
        error_class: error_class_name,
        error_message: error.message,
        notification_type: :email_delivery_error
      )
    end

    # Helper method to create a general notification log data object
    sig do
      params(
        notification_type: Symbol,
        message: String,
        source: Symbol
      ).returns(NotificationLogData)
    end
    def self.create_notification_log_data(notification_type, message, source = :app)
      # Create notification data
      NotificationLogData.new(
        src: source,
        evt: :notification,
        msg: message,
        notification_type: notification_type
      )
    end

    # Helper method to extract recipients from an error
    sig { params(error: StandardError).returns(String) }
    def self.extract_recipients(error)
      # Extract recipient info if available
      if error.respond_to?(:recipients) && T.unsafe(error).recipients.present?
        T.unsafe(error).recipients.join(", ")
      else
        "unknown"
      end
    end
  end
end
