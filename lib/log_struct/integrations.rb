# typed: strict
# frozen_string_literal: true

require_relative "integrations/integration_interface"
require_relative "integrations/active_job"
require_relative "integrations/rack_error_handler"
require_relative "integrations/host_authorization"
require_relative "integrations/action_mailer"
require_relative "integrations/lograge"
require_relative "integrations/shrine"
require_relative "integrations/sidekiq"
require_relative "integrations/active_storage"
require_relative "integrations/carrierwave"
require_relative "integrations/sorbet"

module LogStruct
  module Integrations
    extend T::Sig

    sig { void }
    def self.setup_integrations
      config = LogStruct.config

      # Set up each integration with consistent configuration pattern
      Integrations::Lograge.setup(config) if config.integrations.enable_lograge
      Integrations::ActionMailer.setup(config) if config.integrations.enable_actionmailer
      Integrations::ActiveJob.setup(config) if config.integrations.enable_activejob
      Integrations::Sidekiq.setup(config) if config.integrations.enable_sidekiq
      Integrations::HostAuthorization.setup(config) if config.integrations.enable_host_authorization
      Integrations::RackErrorHandler.setup(config) if config.integrations.enable_rack_error_handler
      Integrations::Shrine.setup(config) if config.integrations.enable_shrine
      Integrations::ActiveStorage.setup(config) if config.integrations.enable_activestorage
      Integrations::CarrierWave.setup(config) if config.integrations.enable_carrierwave
      Integrations::Sorbet.setup(config) if config.integrations.enable_sorbet_error_handlers
    end
  end
end
