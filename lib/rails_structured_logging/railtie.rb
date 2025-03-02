# typed: true
# frozen_string_literal: true

require "rails"

module RailsStructuredLogging
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    initializer "rails_structured_logging.setup" do |app|
      next unless RailsStructuredLogging.enabled?

      # Set up the Rails logger formatter
      ::Rails.logger.formatter = LogFormatter.new

      RailsStructuredLogging::Integrations.setup_integrations
    end
  end
end
