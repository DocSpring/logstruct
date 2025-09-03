# typed: strict
# frozen_string_literal: true

require "active_support/notifications"

module LogStruct
  module ConfigStruct
    class Integrations < T::Struct
      include Sorbet::SerializeSymbolKeys

      # Enable or disable Sorbet error handler integration
      # Default: true
      prop :enable_sorbet_error_handlers, T::Boolean, default: true

      # Enable or disable Lograge integration
      # Default: true
      prop :enable_lograge, T::Boolean, default: true

      # Custom options for Lograge
      # Default: nil
      prop :lograge_custom_options, T.nilable(Handlers::LogrageCustomOptions), default: nil

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
      prop :enable_activestorage, T::Boolean, default: true

      # Enable or disable CarrierWave integration
      # Default: true
      prop :enable_carrierwave, T::Boolean, default: true

      # Enable or disable GoodJob integration
      # Default: true
      prop :enable_goodjob, T::Boolean, default: true

      # Enable SemanticLogger integration for high-performance logging
      # Default: true
      prop :enable_semantic_logger, T::Boolean, default: true

      # Enable colored JSON output in development
      # Default: true
      prop :enable_color_output, T::Boolean, default: true

      # Color configuration for JSON output
      # Default: nil (uses SemanticLogger defaults)
      prop :color_map, T.nilable(T::Hash[Symbol, Symbol]), default: nil

      # Filter noisy loggers (ActionView, etc.)
      # Default: false
      prop :filter_noisy_loggers, T::Boolean, default: false
    end
  end
end
