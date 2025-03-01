# typed: true
# frozen_string_literal: true

require_relative "enums"
require_relative "sorbet"

begin
  require "action_mailer"
rescue LoadError
  # actionmailer gem is not available, integration will be skipped
end

if defined?(::ActionMailer)
  require_relative "action_mailer/logger"
  require_relative "action_mailer/metadata_collection"
  require_relative "action_mailer/event_logging"
  require_relative "action_mailer/error_handling"
  require_relative "action_mailer/callbacks"
end

module RailsStructuredLogging
  # ActionMailer integration for structured logging
  module ActionMailer
    include RailsStructuredLogging::TypedSig
    extend T::Sig

    class << self
      extend T::Sig

      # Set up ActionMailer structured logging
      sig { void }
      def setup
        return unless defined?(::ActionMailer)
        return unless RailsStructuredLogging.enabled?
        return unless RailsStructuredLogging.configuration.actionmailer_integration_enabled

        # Silence default ActionMailer logs (we use our own structured logging)
        # This is required because we replace the logging using our own callbacks
        ::ActionMailer::Base.logger = ::Logger.new(File::NULL) if defined?(::ActionMailer::Base)

        # Include our modules directly into ::ActionMailer::Base
        ::ActiveSupport.on_load(:action_mailer) do
          include RailsStructuredLogging::ActionMailer::EventLogging
          include RailsStructuredLogging::ActionMailer::ErrorHandling
        end

        # Set up callbacks for Rails 7.0.x (not needed for Rails 7.1+)
        setup_callbacks_for_rails_7_0
      end

      private

      # Set up callbacks for Rails 7.0.x
      sig { void }
      def setup_callbacks_for_rails_7_0
        return if ::Rails.gem_version >= Gem::Version.new("7.1.0")

        # Include the callbacks module in ::ActionMailer::Base
        ::ActiveSupport.on_load(:action_mailer) do
          include RailsStructuredLogging::ActionMailer::Callbacks
        end

        # Patch MessageDelivery to run the callbacks
        RailsStructuredLogging::ActionMailer::Callbacks.patch_message_delivery
      end
    end
  end
end
