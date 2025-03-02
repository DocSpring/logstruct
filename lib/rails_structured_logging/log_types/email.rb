# typed: strict
# frozen_string_literal: true

require_relative "base"
require_relative "../enums"

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Email delivery log data class
    class EmailLogData < BaseLogData
      extend T::Sig

      sig { returns(T.nilable(String)) }
      attr_reader :message_id

      sig { returns(T.nilable(String)) }
      attr_reader :mailer_class

      sig { returns(T.nilable(String)) }
      attr_reader :mailer_action

      sig { returns(T.nilable(String)) }
      attr_reader :to

      sig { returns(T.nilable(String)) }
      attr_reader :cc

      sig { returns(T.nilable(String)) }
      attr_reader :bcc

      sig { returns(T.nilable(String)) }
      attr_reader :subject

      # Initialize with all fields
      sig do
        params(
          src: Symbol,
          evt: Symbol,
          ts: T.nilable(Time),
          msg: T.nilable(String),
          message_id: T.nilable(String),
          mailer_class: T.nilable(String),
          mailer_action: T.nilable(String),
          to: T.nilable(String),
          cc: T.nilable(String),
          bcc: T.nilable(String),
          subject: T.nilable(String)
        ).void
      end
      def initialize(src:, evt:, ts: nil, msg: nil, message_id: nil, mailer_class: nil,
        mailer_action: nil, to: nil, cc: nil, bcc: nil, subject: nil)
        super(src: src, evt: evt, ts: ts, msg: msg)
        @message_id = message_id
        @mailer_class = mailer_class
        @mailer_action = mailer_action
        @to = to
        @cc = cc
        @bcc = bcc
        @subject = subject
      end

      # Convert to hash for logging
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        super.merge({
          message_id: @message_id,
          mailer_class: @mailer_class,
          mailer_action: @mailer_action,
          to: @to,
          cc: @cc,
          bcc: @bcc,
          subject: @subject
        }.compact)
      end
    end

    # Valid email event types
    EMAIL_EVENT_TYPES = T.let(
      %i[email_delivery email_delivered email_error].freeze,
      T::Array[Symbol]
    )

    # Helper method to create an email log data object
    sig do
      params(
        mailer: T.untyped,
        message: T.nilable(String),
        event_type: Symbol
      ).returns(EmailLogData)
    end
    def self.create_email_log_data(mailer, message = nil, event_type = :email_delivery)
      # Validate event type
      raise ArgumentError, "Invalid email event type: #{event_type}" unless EMAIL_EVENT_TYPES.include?(event_type)

      # Create email log data
      EmailLogData.new(
        src: Enums::SourceType::ActionMailer.serialize,
        evt: event_type,
        msg: message,
        message_id: T.unsafe(mailer).respond_to?(:message) ? T.unsafe(mailer).message&.message_id : nil,
        mailer_class: T.unsafe(mailer).class.name,
        mailer_action: T.unsafe(mailer).respond_to?(:action_name) ? T.unsafe(mailer).action_name : nil,
        to: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.to).join(", ") : nil,
        cc: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.cc).join(", ") : nil,
        bcc: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.bcc).join(", ") : nil,
        subject: T.unsafe(mailer).respond_to?(:message) ? T.unsafe(mailer).message&.subject : nil
      )
    end
  end
end
