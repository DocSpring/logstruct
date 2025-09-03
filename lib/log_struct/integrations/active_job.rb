# typed: strict
# frozen_string_literal: true

begin
  require "active_job"
  require "active_job/log_subscriber"
rescue LoadError
  # ActiveJob gem is not available, integration will be skipped
end

require_relative "active_job/log_subscriber" if defined?(::ActiveJob::LogSubscriber)

module LogStruct
  module Integrations
    # ActiveJob integration for structured logging
    module ActiveJob
      extend T::Sig
      extend IntegrationInterface

      # Set up ActiveJob structured logging
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::ActiveJob::LogSubscriber)
        return nil unless config.enabled
        return nil unless config.integrations.enable_activejob

        ::ActiveSupport.on_load(:active_job) do
          # Detach the default text formatter
          ::ActiveJob::LogSubscriber.detach_from :active_job

          # Attach our structured formatter
          Integrations::ActiveJob::LogSubscriber.attach_to :active_job
        end
        true
      end
    end
  end
end
