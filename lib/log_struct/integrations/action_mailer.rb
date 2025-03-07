# typed: strict
# frozen_string_literal: true

begin
  require "action_mailer"
rescue LoadError
  # actionmailer gem is not available, integration will be skipped
end

if defined?(::ActionMailer)
  require "logger"
  require_relative "action_mailer/metadata_collection"
  require_relative "action_mailer/event_logging"
  require_relative "action_mailer/error_handling"
  require_relative "action_mailer/callbacks"
end

module LogStruct
  module Integrations
    # ActionMailer integration for structured logging
    module ActionMailer
      extend T::Sig
      extend IntegrationInterface

      # Set up ActionMailer structured logging
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless defined?(::ActionMailer)
        return unless config.enabled
        return unless config.integrations.enable_actionmailer

        # Silence default ActionMailer logs (we use our own structured logging)
        # This is required because we replace the logging using our own callbacks
        if defined?(::ActionMailer::Base)
          ::ActionMailer::Base.logger = ::Logger.new(File::NULL)
        end

        # Register our custom observers and handlers
        # Registering these at the class level means all mailers will use them
        ActiveSupport.on_load(:action_mailer) { prepend LogStruct::Integrations::ActionMailer::MetadataCollection }
        ActiveSupport.on_load(:action_mailer) { prepend LogStruct::Integrations::ActionMailer::EventLogging }
        ActiveSupport.on_load(:action_mailer) { prepend LogStruct::Integrations::ActionMailer::ErrorHandling }
        ActiveSupport.on_load(:action_mailer) { prepend LogStruct::Integrations::ActionMailer::Callbacks }
      end
    end
  end
end
