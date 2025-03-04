# typed: strict
# frozen_string_literal: true

require "rails"
require_relative "formatter"

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

    # Setup all integrations after logger setup is complete
    initializer "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      # Set up all integrations
      Integrations.setup_integrations
    end
  end
end
