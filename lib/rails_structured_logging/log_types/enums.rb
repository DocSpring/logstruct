# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative '../constants'

module RailsStructuredLogging
  module LogTypes
    extend T::Sig

    # Define source types as an enum
    class SourceType < T::Enum
      extend T::Sig

      enums do
        Rails = new(Constants::SRC_RAILS)
        Sidekiq = new(Constants::SRC_SIDEKIQ)
        Shrine = new(Constants::SRC_SHRINE)
        ActionMailer = new(Constants::SRC_ACTIONMAILER)
        ActiveJob = new(Constants::SRC_ACTIVEJOB)
        Mailer = new(:mailer) # For notification events
        App = new(:app) # For application-specific notifications
      end
    end

    # Define event types as an enum
    class EventType < T::Enum
      extend T::Sig

      enums do
        SecurityViolation = new(Constants::EVT_SECURITY_VIOLATION)
        RequestError = new(Constants::EVT_REQUEST_ERROR)
        EmailDelivery = new(Constants::EVT_EMAIL_DELIVERY)
        JobExecution = new(Constants::EVT_JOB_EXECUTION)
        FileOperation = new(Constants::EVT_FILE_OPERATION)
        Notification = new(Constants::EVT_NOTIFICATION)
      end
    end

    # Define notification types as an enum
    class NotificationType < T::Enum
      extend T::Sig

      enums do
        EmailDeliveryError = new(:email_delivery_error)
        SystemAlert = new(:system_alert)
        UserAction = new(:user_action)
      end
    end

    # Define violation types as an enum
    class ViolationType < T::Enum
      extend T::Sig

      enums do
        IpSpoof = new(Constants::VIOLATION_TYPE_IP_SPOOF)
        Csrf = new(Constants::VIOLATION_TYPE_CSRF)
        BlockedHost = new(Constants::VIOLATION_TYPE_BLOCKED_HOST)
      end
    end
  end
end
