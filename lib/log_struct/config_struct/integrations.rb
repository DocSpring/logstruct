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

      # Prefer production-style JSON output in development when LogStruct is enabled.
      # This makes it easy to preview exactly what production logs will look like
      # when you opt-in to LogStruct locally (via LOGSTRUCT_ENABLED=true or config).
      # Default: true
      prop :prefer_json_in_development, T::Boolean, default: true

      # Color configuration for JSON output
      # Default: nil (uses SemanticLogger defaults)
      prop :color_map, T.nilable(T::Hash[Symbol, Symbol]), default: nil

      # Filter noisy loggers (ActionView, etc.)
      # Default: false
      prop :filter_noisy_loggers, T::Boolean, default: false

      # Enable SQL query logging through ActiveRecord instrumentation
      # Default: false (can be resource intensive)
      prop :enable_sql_logging, T::Boolean, default: false

      # Only log SQL queries slower than this threshold (in milliseconds)
      # Set to 0 or nil to log all queries
      # Default: 100.0 (log queries taking >100ms)
      prop :sql_slow_query_threshold, T.nilable(Float), default: 100.0

      # Include bind parameters in SQL logs (disable in production for security)
      # Default: true in development/test, false in production
      prop :sql_log_bind_params, T::Boolean, factory: -> { !defined?(::Rails) || !::Rails.respond_to?(:env) || !::Rails.env.production? }

      # Enable Ahoy (analytics events) integration
      # Default: true (safe no-op unless Ahoy is defined)
      prop :enable_ahoy, T::Boolean, default: true

      # Enable ActiveModelSerializers integration
      # Default: true (safe no-op unless ActiveModelSerializers is defined)
      prop :enable_active_model_serializers, T::Boolean, default: true

      # Enable dotenv-rails integration (convert to structured logs)
      # Default: true
      prop :enable_dotenv, T::Boolean, default: true
    end
  end
end
