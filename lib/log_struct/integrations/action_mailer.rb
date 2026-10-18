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
          # Silence default ActionMailer logs (we use our own structured logging)
          self.logger = ::Logger.new(File::NULL)

          prepend LogStruct::Integrations::ActionMailer::EventLogging
          prepend LogStruct::Integrations::ActionMailer::ErrorHandling
          prepend LogStruct::Integrations::ActionMailer::MetadataCollection
        end

        true
      end
    end
  end
end
