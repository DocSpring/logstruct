# typed: strict
# frozen_string_literal: true

module LogStruct
  module Enums
    # Define source types as an enum
    class SourceType < T::Enum
      enums do
        Rails = new(:rails)
        Sidekiq = new(:sidekiq)
        Shrine = new(:shrine)
        ActionMailer = new(:actionmailer)
        ActiveJob = new(:activejob)
        Mailer = new(:mailer) # For notification events
        App = new(:app) # For application-specific notifications
      end
    end
  end
end
