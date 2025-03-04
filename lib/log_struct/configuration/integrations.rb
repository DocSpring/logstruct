# typed: strict
# frozen_string_literal: true

module LogStruct
  class Configuration
    class Integrations < T::Struct
      extend T::Sig

      # Enable or disable Lograge integration
      # Default: true
      prop :enable_lograge, T::Boolean, default: true

      # Custom options for Lograge
      # Default: nil
      prop :lograge_custom_options, T.nilable(T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))

      # Enable or disable ActionMailer integration
      # Default: true
      prop :enable_actionmailer, T::Boolean, default: true

      # Enable or disable host authorization logging
      # Default: true
      prop :enable_host_authorization, T::Boolean, default: true

      # Enable or disable ActiveJob integration
      # Default: true
      prop :enable_activejob, T::Boolean, default: true

      # Enable or disable Rack middleware
      # Default: true
      prop :enable_rack_error_handler, T::Boolean, default: true

      # Enable or disable Sidekiq integration
      # Default: true
      prop :enable_sidekiq, T::Boolean, default: true

      # Enable or disable Shrine integration
      # Default: true
      prop :enable_shrine, T::Boolean, default: true

      # Enable or disable ActiveStorage integration
      # Default: true
      prop :enable_active_storage, T::Boolean, default: true

      # Enable or disable CarrierWave integration
      # Default: true
      prop :enable_carrierwave, T::Boolean, default: true

      sig { void }
      def initialize
        super(
          enable_lograge: true,
          lograge_custom_options: nil,
          enable_actionmailer: true,
          enable_host_authorization: true,
          enable_activejob: true,
          enable_rack_error_handler: true,
          enable_sidekiq: true,
          enable_shrine: true,
          enable_active_storage: true,
          enable_carrierwave: true
        )
      end
    end
  end
end
