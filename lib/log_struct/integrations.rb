# typed: strict
# frozen_string_literal: true

require_relative "integrations/integration_interface"
require_relative "integrations/request_context"
require_relative "integrations/active_job"
require_relative "integrations/active_record"
require_relative "integrations/rack_error_handler"
require_relative "integrations/host_authorization"
require_relative "integrations/action_mailer"
require_relative "integrations/lograge"
require_relative "integrations/shrine"
require_relative "integrations/sidekiq"
require_relative "integrations/good_job"
require_relative "integrations/active_storage"
require_relative "integrations/carrierwave"
require_relative "integrations/sorbet"
require_relative "integrations/ahoy"
require_relative "integrations/active_model_serializers"
require_relative "integrations/dotenv"
require_relative "integrations/puma"

module LogStruct
  module Integrations
    extend T::Sig

    # Register generic initializers on the Railtie to keep integration
    # wiring centralized (boot replay interception and resolution).
    sig { params(railtie: T.untyped).void }
    def self.setup_initializers(railtie)
      # Intercept any boot-time replays (e.g., dotenv) before those railties run
      railtie.initializer "logstruct.intercept_boot_replays", before: "dotenv" do
        LogStruct::Integrations::Dotenv.intercept_logger_setter!
      end

      # Decide which set of boot logs to emit after user initializers
      railtie.initializer "logstruct.resolve_boot_logs", after: :load_config_initializers do
        LogStruct::Integrations::Dotenv.resolve_boot_logs!
      end
    end

    sig { params(stage: Symbol).void }
    def self.setup_integrations(stage: :all)
      config = LogStruct.config

      case stage
      when :non_middleware
        setup_non_middleware_integrations(config)
      when :middleware
        setup_middleware_integrations(config)
      when :all
        setup_non_middleware_integrations(config)
        setup_middleware_integrations(config)
      else
        raise ArgumentError, "Unknown integration stage: #{stage}"
      end
    end

    sig { params(config: LogStruct::Configuration).void }
    def self.setup_non_middleware_integrations(config)
      Integrations::Lograge.setup(config) if config.integrations.enable_lograge
      Integrations::ActionMailer.setup(config) if config.integrations.enable_actionmailer
      Integrations::ActiveJob.setup(config) if config.integrations.enable_activejob
      Integrations::ActiveRecord.setup(config) if config.integrations.enable_sql_logging
      Integrations::Sidekiq.setup(config) if config.integrations.enable_sidekiq
      Integrations::GoodJob.setup(config) if config.integrations.enable_goodjob
      Integrations::Ahoy.setup(config) if config.integrations.enable_ahoy
      Integrations::ActiveModelSerializers.setup(config) if config.integrations.enable_active_model_serializers
      Integrations::Shrine.setup(config) if config.integrations.enable_shrine
      Integrations::ActiveStorage.setup(config) if config.integrations.enable_activestorage
      Integrations::CarrierWave.setup(config) if config.integrations.enable_carrierwave
      Integrations::Sorbet.setup(config) if config.integrations.enable_sorbet_error_handlers
      if config.enabled && config.integrations.enable_dotenv
        Integrations::Dotenv.setup(config)
      end
      Integrations::Puma.setup(config) if config.integrations.enable_puma
    end

    sig { params(config: LogStruct::Configuration).void }
    def self.setup_middleware_integrations(config)
      Integrations::RequestContext.setup(config)
      Integrations::HostAuthorization.setup(config) if config.integrations.enable_host_authorization
      Integrations::RackErrorHandler.setup(config) if config.integrations.enable_rack_error_handler
    end

    private_class_method :setup_non_middleware_integrations, :setup_middleware_integrations
  end
end
