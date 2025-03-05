# typed: strict
# frozen_string_literal: true

module LogStruct
  class ErrorReporter < T::Enum
    enums do
      RailsLogger = new(:rails_logger)
      Sentry = new(:sentry)
      Bugsnag = new(:bugsnag)
      Rollbar = new(:rollbar)
      Honeybadger = new(:honeybadger)
    end
  end
end
