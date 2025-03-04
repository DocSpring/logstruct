# typed: strict
# frozen_string_literal: true

module LogStruct
  class Integrations < T::Struct
    extend T::Sig

    # Enable or disable Lograge integration
    # Default: true
    prop :lograge_enabled, T::Boolean

    # Custom options for Lograge
    # Default: nil
    prop :lograge_custom_options, T.nilable(T.proc.params(event: ActiveSupport::Notifications::Event, options: T.untyped).returns(T.untyped))

    # Enable or disable ActionMailer integration
    # Default: true
    prop :actionmailer_enabled, T::Boolean

    # Enable or disable host authorization logging
    # Default: true
    prop :host_authorization_enabled, T::Boolean

    # Enable or disable ActiveJob integration
    # Default: true
    prop :activejob_enabled, T::Boolean

    # Enable or disable Rack middleware
    # Default: true
    prop :rack_middleware_enabled, T::Boolean

    # Enable or disable Sidekiq integration
    # Default: true
    prop :sidekiq_enabled, T::Boolean

    # Enable or disable Shrine integration
    # Default: true
    prop :shrine_enabled, T::Boolean

    # Enable or disable ActiveStorage integration
    # Default: true
    prop :active_storage_enabled, T::Boolean

    # Enable or disable CarrierWave integration
    # Default: true
    prop :carrierwave_enabled, T::Boolean

    sig { void }
    def initialize
      super(
        lograge_enabled: true,
        lograge_custom_options: nil,
        actionmailer_enabled: true,
        host_authorization_enabled: true,
        activejob_enabled: true,
        rack_middleware_enabled: true,
        sidekiq_enabled: true,
        shrine_enabled: true,
        active_storage_enabled: true,
        carrierwave_enabled: true
      )
    end
  end
end
