# typed: strict
# frozen_string_literal: true

require "rails"
require "semantic_logger"
require_relative "formatter"
require_relative "semantic_logger/setup"

module LogStruct
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    # Configure early, right after logger initialization
    initializer "logstruct.configure_logger", after: :initialize_logger do |app|
      next unless LogStruct.enabled?

      # Apply TaggedLogging monkey patch only when enabled
      require_relative "monkey_patches/active_support/tagged_logging/formatter"

      # Use SemanticLogger for powerful logging features
      LogStruct::SemanticLogger::Setup.configure_semantic_logger(app)
    end

    # Setup all integrations after logger setup is complete
    initializer "logstruct.setup", before: :build_middleware_stack do |app|
      next unless LogStruct.enabled?

      # Merge Rails filter parameters into our filters
      LogStruct.merge_rails_filter_parameters!

      # Set up all integrations
      Integrations.setup_integrations
    end
  end
end
