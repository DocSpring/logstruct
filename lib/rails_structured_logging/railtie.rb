# frozen_string_literal: true

require 'rails'

module RailsStructuredLogging
  # Railtie to integrate with Rails
  class Railtie < Rails::Railtie
    initializer 'rails_structured_logging.setup' do |app|
      # Set up structured logging
      RailsStructuredLogging.setup

      # Silence noisy loggers if enabled
      if RailsStructuredLogging.enabled? && RailsStructuredLogging.configuration.silence_noisy_loggers
        app.config.after_initialize do
          dev_null_logger = Logger.new('/dev/null')

          # Silence Ahoy if present
          Ahoy.logger = dev_null_logger if defined?(Ahoy)

          # Silence ActiveModelSerializers if present
          ActiveModelSerializers.logger = dev_null_logger if defined?(ActiveModelSerializers)

          # Silence default ActionMailer logs (we use our own structured logging)
          ActionMailer::Base.logger = dev_null_logger if defined?(ActionMailer::Base)
        end
      end
    end
  end
end
