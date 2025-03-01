# frozen_string_literal: true

require 'rails'

module RailsStructuredLogging
  # Railtie to integrate with Rails
  class Railtie < Rails::Railtie
    initializer 'rails_structured_logging.setup' do |app|
      # Set up ActiveJob integration
      if RailsStructuredLogging.enabled? && RailsStructuredLogging.configuration.activejob_integration_enabled
        ActiveSupport.on_load(:active_job) do
          RailsStructuredLogging::ActiveJob.setup
        end
      end

      # Set up Rack middleware for error logging
      RailsStructuredLogging::Rack.setup(app)

      # Set up Sidekiq integration if Sidekiq is loaded later
      if RailsStructuredLogging.enabled? && RailsStructuredLogging.configuration.sidekiq_integration_enabled
        # Ensure Sidekiq integration is set up when Sidekiq is loaded
        ActiveSupport.on_load(:sidekiq) do
          RailsStructuredLogging::Sidekiq.setup
        end
      end

      # Set up Shrine integration
      if RailsStructuredLogging.enabled? && RailsStructuredLogging.configuration.shrine_integration_enabled
        app.config.after_initialize do
          RailsStructuredLogging::Shrine.setup if defined?(::Shrine)
        end
      end
    end
  end
end
