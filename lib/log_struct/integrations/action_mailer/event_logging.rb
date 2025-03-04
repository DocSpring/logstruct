# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Handles logging of email delivery events
      module EventLogging
        extend ActiveSupport::Concern
        extend T::Sig
        extend T::Helpers
        requires_ancestor { ::ActionMailer::Base }

        included do
          T.bind(self, ActionMailer::Callbacks::ClassMethods)

          # Add callbacks for delivery events
          before_deliver :log_email_delivery
          after_deliver :log_email_delivered
        end

        protected

        # Log when an email is about to be delivered
        sig { void }
        def log_email_delivery
          log_mailer_event(LogEvent::Delivery)
        end

        # Log when an email is delivered
        sig { void }
        def log_email_delivered
          log_mailer_event(LogEvent::Delivered)
        end

        private

        # Log a mailer event with the given event type
        sig do
          params(event_type: Log::ActionMailer::EmailLogEvent,
            level: Symbol,
            additional_data: T::Hash[Symbol, T.untyped]).returns(T.untyped)
        end
        def log_mailer_event(event_type, level = :info, additional_data = {})
          # Get message (self refers to the mailer instance)
          mailer_message = message if respond_to?(:message)

          # Prepare data for the log entry
          data = {
            message_id: extract_message_id,
            mailer_class: self.class.to_s,
            mailer_action: action_name.to_s
          }.compact

          # Add any additional metadata
          MetadataCollection.add_message_metadata(self, data)
          MetadataCollection.add_context_metadata(self, data)
          data.merge!(additional_data) if additional_data.present?

          # Extract email fields (these will be filtered if filter_emails=true)
          to = mailer_message&.to
          from = mailer_message&.from&.first
          subject = mailer_message&.subject

          # Create a structured log entry
          log_data = Log::ActionMailer.new(
            event: event_type,
            level: LogLevel::Info,
            to: to,
            from: from,
            subject: subject,
            data: data
          )
          LogStruct.log(log_data)
          log_data
        end

        # Extract message ID from the mailer
        sig { returns(T.nilable(String)) }
        def extract_message_id
          return nil unless respond_to?(:message)

          mail_message = message
          return nil unless mail_message.respond_to?(:message_id)

          mail_message.message_id
        end
      end
    end
  end
end
