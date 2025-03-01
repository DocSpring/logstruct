# frozen_string_literal: true

module RailsStructuredLogging
  module ActionMailer
    # Handles logging of email delivery events
    module EventLogging
      extend ActiveSupport::Concern

      included do
        # Add callbacks for delivery events
        before_deliver :log_email_delivery
        after_deliver :log_email_delivered
      end

      protected

      # Log when an email is about to be delivered
      def log_email_delivery
        log_mailer_event('email_delivery')
      end

      # Log when an email is delivered
      def log_email_delivered
        log_mailer_event('email_delivered')
      end

      private

      # Log a mailer event with the given event type
      def log_mailer_event(event_type, level = :info, additional_data = {})
        log_data = Logger.build_base_log_data(self, event_type)
        log_data.merge!(additional_data) if additional_data.present?
        Logger.log_to_rails(log_data, level)
        log_data
      end
    end
  end
end
