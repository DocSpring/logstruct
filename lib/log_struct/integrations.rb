# typed: strict
# frozen_string_literal: true

require_relative "integrations/active_job"
require_relative "integrations/rack"
require_relative "integrations/host_authorization"
require_relative "integrations/action_mailer"
require_relative "integrations/lograge"
require_relative "integrations/shrine"
require_relative "integrations/sidekiq"
require_relative "integrations/active_storage"
require_relative "integrations/carrierwave"

module LogStruct
  module Integrations
    sig { void }
    def self.setup_integrations
      config = LogStruct.configuration

      Integrations::Lograge.setup if config.lograge_enabled
      Integrations::ActionMailer.setup if config.actionmailer_integration_enabled
      Integrations::ActiveJob.setup if config.activejob_integration_enabled
      Integrations::Sidekiq.setup if config.sidekiq_integration_enabled
      Integrations::HostAuthorization.setup if config.host_authorization_enabled
      Integrations::Rack.setup(::Rails.application) if config.rack_middleware_enabled
      Integrations::Shrine.setup if config.shrine_integration_enabled
      Integrations::ActiveStorage.setup if config.active_storage_integration_enabled
      Integrations::CarrierWave.setup if config.carrierwave_integration_enabled
    end
  end
end
