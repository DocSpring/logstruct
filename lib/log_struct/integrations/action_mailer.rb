# typed: strict
# frozen_string_literal: true

begin
  require "action_mailer"
rescue LoadError
  # actionmailer gem is not available, integration will be skipped
end

if defined?(::ActionMailer)
  require_relative "action_mailer/metadata_collection"
  require_relative "action_mailer/event_logging"
  require_relative "action_mailer/error_handling"
  require_relative "action_mailer/fallback_error_handlers"
end

module LogStruct
  module Integrations
    # ActionMailer integration for structured logging
    module ActionMailer
      extend T::Sig
      extend IntegrationInterface

      # Set up ActionMailer structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::ActionMailer)
        return nil unless config.enabled
        return nil unless config.integrations.enable_actionmailer

        # Register our custom observers and handlers on all mailers. The hook runs right away
        # if ActionMailer::Base is already loaded.
        ActiveSupport.on_load(:action_mailer) do
          # LogStruct's delivery lines replace Rails' mail lines, which also log the whole mail at debug level.
          # Mailers keep their logger, so an app's own logger calls in a mailer are still logged.
          ::ActionMailer::LogSubscriber.detach_from(:action_mailer) if defined?(::ActionMailer::LogSubscriber)

          prepend LogStruct::Integrations::ActionMailer::EventLogging
          prepend LogStruct::Integrations::ActionMailer::ErrorHandling
          prepend LogStruct::Integrations::ActionMailer::MetadataCollection
        end

        true
      end

      # Where LogStruct doesn't set up ActionMailer, mailers still get the error handlers they can name in
      # rescue_from (see FallbackErrorHandlers)
      sig { params(config: LogStruct::Configuration).void }
      def self.setup_fallback_error_handlers(config)
        return unless defined?(::ActionMailer)
        return if config.enabled && config.integrations.enable_actionmailer

        ActiveSupport.on_load(:action_mailer) do
          next if include?(LogStruct::Integrations::ActionMailer::FallbackErrorHandlers)

          include LogStruct::Integrations::ActionMailer::FallbackErrorHandlers
          extend LogStruct::Integrations::ActionMailer::FallbackErrorHandlers::ClassMethods
        end
      end
    end
  end
end
