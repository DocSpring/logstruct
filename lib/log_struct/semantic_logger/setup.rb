# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "formatter"
require_relative "color_formatter"
require_relative "logger"

module LogStruct
  module SemanticLogger
    # Handles setup and configuration of SemanticLogger for Rails
    module Setup
      extend T::Sig

      sig { params(app: T.untyped).void }
      def self.configure_semantic_logger(app)
        # Set SemanticLogger configuration
        ::SemanticLogger.application = Rails.application.class.module_parent_name
        ::SemanticLogger.environment = Rails.env

        # Determine log level from Rails config
        log_level = determine_log_level(app)
        ::SemanticLogger.default_level = log_level

        # Clear existing appenders
        ::SemanticLogger.clear_appenders!

        # Add appropriate appenders based on environment
        add_appenders(app)

        # Replace Rails.logger with SemanticLogger
        replace_rails_logger(app)
      end

      sig { params(app: T.untyped).returns(Symbol) }
      def self.determine_log_level(app)
        if app.config.log_level
          app.config.log_level
        elsif Rails.env.production?
          :info
        elsif Rails.env.test?
          :warn
        else
          :debug
        end
      end

      sig { params(app: T.untyped).void }
      def self.add_appenders(app)
        config = LogStruct.config

        # Determine output destination
        io = determine_output(app)

        if Rails.env.development? && config.integrations.enable_color_output
          # Use our colorized LogStruct formatter for development
          ::SemanticLogger.add_appender(
            io: io,
            formatter: LogStruct::SemanticLogger::ColorFormatter.new(
              color_map: config.integrations.color_map
            ),
            filter: determine_filter
          )
        else
          # Use our custom JSON formatter
          ::SemanticLogger.add_appender(
            io: io,
            formatter: LogStruct::SemanticLogger::Formatter.new,
            filter: determine_filter
          )
        end

        # Add file appender if configured
        if app.config.paths["log"].first && !ENV["RAILS_LOG_TO_STDOUT"]
          ::SemanticLogger.add_appender(
            file_name: app.config.paths["log"].first,
            formatter: LogStruct::SemanticLogger::Formatter.new,
            filter: determine_filter
          )
        end
      end

      sig { params(app: T.untyped).returns(T.any(IO, StringIO)) }
      def self.determine_output(app)
        if ENV["RAILS_LOG_TO_STDOUT"].present?
          $stdout
        elsif Rails.env.test?
          # Use StringIO for tests to avoid cluttering test output
          StringIO.new
        else
          $stdout
        end
      end

      sig { returns(T.nilable(Regexp)) }
      def self.determine_filter
        # Filter out noisy loggers if configured
        config = LogStruct.config
        return nil unless config.integrations.filter_noisy_loggers

        # Common noisy loggers to filter
        /\A(ActionView|ActionController::RoutingError|ActiveRecord::SchemaMigration)/
      end

      sig { params(app: T.untyped).void }
      def self.replace_rails_logger(app)
        # Create new SemanticLogger instance
        logger = LogStruct::SemanticLogger::Logger.new("Rails")

        # Replace Rails.logger
        Rails.logger = logger

        # Also replace various component loggers
        ActiveRecord::Base.logger = logger if defined?(ActiveRecord::Base)
        ActionController::Base.logger = logger if defined?(ActionController::Base)
        ActionMailer::Base.logger = logger if defined?(ActionMailer::Base)
        ActiveJob::Base.logger = logger if defined?(ActiveJob::Base)
        ActionView::Base.logger = logger if defined?(ActionView::Base)
        ActionCable.server.config.logger = logger if defined?(ActionCable)

        # Store reference in app config
        app.config.logger = logger
      end
    end
  end
end
