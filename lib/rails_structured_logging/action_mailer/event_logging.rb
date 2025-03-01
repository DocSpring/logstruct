# frozen_string_literal: true
# typed: true

require_relative '../sorbet'

module RailsStructuredLogging
  module ActionMailer
    # Handles logging of email delivery events
    module EventLogging
      include RailsStructuredLogging::TypedSig
      extend T::Sig
      extend ActiveSupport::Concern

      # We can't use included block with strict typing
      # This will be handled by ActiveSupport::Concern at runtime
      # included do
      #   # Add callbacks for delivery events
      #   before_deliver :log_email_delivery
      #   after_deliver :log_email_delivered
      # end

      protected

      # Log when an email is about to be delivered
      sig { void }
      def log_email_delivery
        log_mailer_event('email_delivery')
      end

      # Log when an email is delivered
      sig { void }
      def log_email_delivered
        log_mailer_event('email_delivered')
      end

      private

      # Log a mailer event with the given event type
      sig { params(event_type: String, level: Symbol, additional_data: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
      def log_mailer_event(event_type, level = :info, additional_data = {})
        log_data = Logger.build_base_log_data(self, event_type)
        log_data.merge!(additional_data) if additional_data.present?
        Logger.log_to_rails(log_data, level)
        log_data
      end
    end
  end
end
