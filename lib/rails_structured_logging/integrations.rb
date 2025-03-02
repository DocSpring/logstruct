# typed: strict
# frozen_string_literal: true

Dir.glob(File.expand_path("integrations/*.rb", __dir__)).sort.each do |file|
  require_relative file
end

module RailsStructuredLogging
  module Integrations
    sig { void }
    def self.setup_integrations
      config = RailsStructuredLogging.configuration

      Integrations::Lograge.setup if config.lograge_enabled
      Integrations::ActionMailer.setup if config.actionmailer_integration_enabled
      Integrations::ActiveJob.setup if config.activejob_integration_enabled
      Integrations::Sidekiq.setup if config.sidekiq_integration_enabled
      Integrations::HostAuthorizationResponseApp.setup if config.host_authorization_enabled
      Integrations::Rack.setup(::Rails.application) if config.rack_middleware_enabled
      Integrations::Shrine.setup if config.shrine_integration_enabled
    end
  end
end
