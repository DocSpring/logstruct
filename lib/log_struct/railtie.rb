# typed: strict
# frozen_string_literal: true

require "rails"
require_relative "logger"
require_relative "logger_utils"

module LogStruct
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    # Configure early, right after logger initialization
    initializer "logstruct.configure_logger", after: :initialize_logger do |app|
      next unless LogStruct.enabled?

      # At this early stage, set formatter on the existing logger
      # This ensures all components get structured logging even if they
      # cache a reference to Rails.logger early
      original_logger = ::Rails.logger
      if original_logger
        original_logger.formatter = LogStruct::Formatter.new
      end
    end

    # Setup complete logging system later, when config is fully loaded
    initializer "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      # If we want a complete logger replacement, do it here
      if LogStruct.config.replace_rails_logger
        original_logger = ::Rails.logger
        logger = LogStruct::LoggerUtils.create_logger(
          LogStruct::Logger,
          original_logger
        )
        
        # Replace Rails.logger and app.config.logger
        ::Rails.logger = logger
        app.config.logger = logger
      end

      # Set up all integrations 
      Integrations.setup_integrations
    end
  end
end
