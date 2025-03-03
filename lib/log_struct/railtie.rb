# typed: true
# frozen_string_literal: true

require "rails"

module LogStruct
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    initializer "logstruct.setup" do |app|
      next unless LogStruct.config.enabled_for_environment?

      # Set up the Rails logger formatter
      ::Rails.logger.formatter = JSONFormatter.new

      Integrations.setup_integrations
    end
  end
end
