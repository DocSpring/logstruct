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
        requires_ancestor { ErrorHandling }

        included do
          T.bind(self, T.class_of(::ActionMailer::Base))

          # Add callbacks for delivery events
          before_deliver :log_email_delivery
          after_deliver :log_email_delivered
        end

        # When this module is prepended (our integration uses prepend), ensure callbacks are registered
        if respond_to?(:prepended)
          prepended do
            T.bind(self, T.class_of(::ActionMailer::Base))

            # Add callbacks for delivery events
            before_deliver :log_email_delivery
            after_deliver :log_email_delivered
          end
        end

        protected

        # Log when an email is about to be delivered
        sig { void }
        def log_email_delivery
          log_mailer_event(Event::Delivery)
        end

        # Log when an email is delivered
        sig { void }
        def log_email_delivered
          # Don't log delivered event if the delivery failed (error was handled with log_and_ignore_error)
          return if logstruct_mail_failed

          log_mailer_event(Event::Delivered)
        end

        private

        # Log a mailer event with the given event type
        sig { params(event_type: LogStruct::Event, level: Symbol, additional_data: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
        def log_mailer_event(event_type, level = :info, additional_data = {})
          # Get message (self refers to the mailer instance)
          mailer_message = message if respond_to?(:message)

          # Prepare universal mailer fields
          message_data = {}
          MetadataCollection.add_message_metadata(self, message_data)

          # Prepare app-specific context data for additional_data
          context_data = {}
          MetadataCollection.add_context_metadata(self, context_data)
          context_data.merge!(additional_data) if additional_data.present?

          # Extract email fields (these will be filtered if email_addresses=true)
          to = mailer_message&.to
          from = mailer_message&.from&.first
          subject = mailer_message&.subject

          base_fields = Log::ActionMailer::BaseFields.new(
            to: to,
            from: from,
            subject: subject,
            message_id: extract_message_id,
            mailer_class: self.class.to_s,
            mailer_action: action_name.to_s,
            attachment_count: message_data[:attachment_count]
          )

          log = case event_type
          when Event::Delivery
            Log::ActionMailer::Delivery.new(
              **base_fields.to_kwargs,
              additional_data: context_data.presence,
              timestamp: Time.now
            )
          when Event::Delivered
            Log::ActionMailer::Delivered.new(
              **base_fields.to_kwargs,
              additional_data: context_data.presence,
              timestamp: Time.now
            )
          else
            return
          end
          LogStruct.info(log)
          log
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
