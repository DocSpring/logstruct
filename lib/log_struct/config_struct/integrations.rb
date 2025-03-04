# typed: strict
# frozen_string_literal: true

require "active_support/notifications"

module LogStruct
  module ConfigStruct
    class Integrations < T::Struct
      include Sorbet::SerializeSymbolKeys

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
    end
  end
end
