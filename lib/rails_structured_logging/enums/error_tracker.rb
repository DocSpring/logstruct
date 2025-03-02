# typed: strict
# frozen_string_literal: true

module RailsStructuredLogging
  module Enums
    class ErrorTracker < T::Enum
      enums do
        Sentry = new(:sentry)
        Bugsnag = new(:bugsnag)
        Rollbar = new(:rollbar)
        Honeybadger = new(:honeybadger)
        Logger = new(:logger)
      end
    end
  end
end
