# typed: strict
# frozen_string_literal: true

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

      Integrations::Lograge.setup if config.integrations.enable_lograge
      Integrations::ActionMailer.setup if config.integrations.enable_actionmailer
      Integrations::ActiveJob.setup if config.integrations.enable_activejob
      Integrations::Sidekiq.setup if config.integrations.enable_sidekiq
      Integrations::HostAuthorization.setup if config.integrations.enable_host_authorization
      Integrations::RackErrorHandler.setup(::Rails.application) if config.integrations.enable_rack_error_handler
      Integrations::Shrine.setup if config.integrations.enable_shrine
      Integrations::ActiveStorage.setup if config.integrations.enable_active_storage
      Integrations::CarrierWave.setup if config.integrations.enable_carrierwave
      Integrations::Sorbet.setup(config) if config.integrations.enable_sorbet_error_handler
    end
  end
end
