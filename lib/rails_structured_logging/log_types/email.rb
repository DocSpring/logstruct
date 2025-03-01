# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative 'base'

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Email delivery log data struct
    class EmailLogData < BaseLogData
      extend T::Sig

      const :message_id, T.nilable(String)
      const :mailer_class, T.nilable(String)
      const :mailer_action, T.nilable(String)
      const :to, T.nilable(String)
      const :cc, T.nilable(String)
      const :bcc, T.nilable(String)
      const :subject, T.nilable(String)
    end

    # Helper method to create an email log data object
    sig do
      params(
        mailer: T.untyped,
        message: T.nilable(String),
        additional_data: T::Hash[T.any(Symbol, String), T.untyped]
      ).returns(EmailLogData)
    end
    def self.create_email_log_data(mailer, message = nil, additional_data = {})
      # Create email log data
      EmailLogData.new(
        src: Constants::SRC_ACTIONMAILER,
        evt: Constants::EVT_EMAIL_DELIVERY,
        msg: message,
        message_id: T.unsafe(mailer).respond_to?(:message) ? T.unsafe(mailer).message&.message_id : nil,
        mailer_class: T.unsafe(mailer).class.name,
        mailer_action: T.unsafe(mailer).respond_to?(:action_name) ? T.unsafe(mailer).action_name : nil,
        to: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.to).join(', ') : nil,
        cc: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.cc).join(', ') : nil,
        bcc: T.unsafe(mailer).respond_to?(:message) ? Array(T.unsafe(mailer).message&.bcc).join(', ') : nil,
        subject: T.unsafe(mailer).respond_to?(:message) ? T.unsafe(mailer).message&.subject : nil,
        additional_data: additional_data
      )
    end
  end
end
