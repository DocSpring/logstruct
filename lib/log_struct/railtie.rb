# typed: true
# frozen_string_literal: true

require "rails"

module LogStruct
  # Railtie to integrate with Rails
  class Railtie < ::Rails::Railtie
    initializer "logstruct.setup" do |app|
      next unless LogStruct.enabled?

      # Set up the Rails logger formatter
      ::Rails.logger.formatter = LogStruct::LogFormatter.new

      LogStruct::Integrations.setup_integrations
    end
  end
end
