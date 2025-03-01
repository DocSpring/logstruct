# frozen_string_literal: true

require_relative "action_mailer/logger"
require_relative "action_mailer/metadata_collection"
require_relative "action_mailer/event_logging"
require_relative "action_mailer/error_handling"

module RailsStructuredLogging
  # ActionMailer integration for structured logging
  module ActionMailer
    extend ActiveSupport::Concern

    included do
      include RailsStructuredLogging::ActionMailer::EventLogging
      include RailsStructuredLogging::ActionMailer::ErrorHandling
    end
  end
end
