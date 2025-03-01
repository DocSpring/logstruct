# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'

module RailsStructuredLogging
  module Enums
    # Define notification types as an enum
    class NotificationType < T::Enum
      extend T::Sig

      enums do
        EmailDeliveryError = new(:email_delivery_error)
        SystemAlert = new(:system_alert)
        UserAction = new(:user_action)
      end
    end
  end
end
