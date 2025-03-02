# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log source types as an enum
  class LogSource < T::Enum
    enums do
      Rails = new(:rails)
      Job = new(:job)
      Sidekiq = new(:sidekiq)
      Mailer = new(:mailer)
      File = new(:file)
      App = new(:app)
    end
  end
end
