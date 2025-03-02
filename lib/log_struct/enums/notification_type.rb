# typed: strict
# frozen_string_literal: true

module LogStruct
  module Enums
    # Define notification types as an enum
    class NotificationType < T::Enum
      enums do
        EmailDeliveryError = new(:email_delivery_error)
        SystemAlert = new(:system_alert)
        UserAction = new(:user_action)
      end
    end
  end
end
