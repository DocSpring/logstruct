# typed: strict
# frozen_string_literal: true

module LogStruct
  # Combined Source class that unifies log and error sources
  class Source < T::Enum
    enums do
      # Error sources
      TypeChecking = new(:type_checking) # For type checking errors (Sorbet)
      LogStruct = new(:logstruct) # Errors from LogStruct itself
      Security = new(:security) # Security-related events

      # Application sources
      Rails = new(:rails) # For request-related logs/errors
      Job = new(:job) # ActiveJob logs/errors
      Storage = new(:storage) # ActiveStorage logs/errors
      Mailer = new(:mailer) # ActionMailer logs/errors
      App = new(:app) # General application logs/errors

      # Third-party gem sources
      Shrine = new(:shrine)
      CarrierWave = new(:carrierwave)
      Sidekiq = new(:sidekiq)
    end
  end
end
