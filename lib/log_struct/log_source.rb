# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log source types as an enum
  class Source < T::Enum
    enums do
      # Rails and Rails-related sources
      Rails = new(:rails)
      Job = new(:job) # ActiveJob
      Storage = new(:storage) # ActiveStorage
      Mailer = new(:mailer) # ActionMailer
      App = new(:app) # Rails application

      # Third-party gems
      Shrine = new(:shrine)
      CarrierWave = new(:carrierwave)
      Sidekiq = new(:sidekiq)
    end
  end
end
