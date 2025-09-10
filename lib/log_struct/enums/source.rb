# typed: strict
# frozen_string_literal: true

module LogStruct
  # Combined Source class that unifies log and error sources
  class Source < T::Enum
    enums do
      # Error sources
      TypeChecking = new(:type_checking) # For type checking errors (Sorbet)
      Security = new(:security) # Security-related events
      # Errors from LogStruct. (Cannot use LogStruct here because it confuses tapioca.)
      Internal = new(:logstruct)

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
      Dotenv = new(:dotenv)
      Puma = new(:puma)
    end
  end
end
