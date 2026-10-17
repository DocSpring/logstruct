# typed: strict
# frozen_string_literal: true

require "semantic_logger"
require_relative "formatter"
require_relative "color_formatter"
require_relative "logger"
require_relative "reopen_after_fork"

module LogStruct
  # LogStruct writes its lines through SemanticLogger. It replaces Rails.logger and the framework loggers with a
  # SemanticLogger logger whose formatter writes LogStruct's JSON lines. SemanticLogger formats and writes each line on
  # a background thread, so a request or job doesn't wait for the write, and it can write to several appenders
  # (STDOUT, a file, a log service) at once.
  module SemanticLogger
    # Sets up SemanticLogger for a Rails app: its level, appenders and formatters, and the loggers it replaces
    module Setup
      extend T::Sig

      # Load hooks for the framework components whose loggers LogStruct replaces
      COMPONENT_LOAD_HOOKS = T.let(
        %i[active_record action_controller action_mailer active_job action_view action_cable].freeze,
        T::Array[Symbol]
      )

      # The logger LogStruct installed, and the loggers it replaced
      @logger = T.let(nil, T.nilable(LogStruct::SemanticLogger::Logger))
      @original_rails_logger = T.let(nil, T.untyped)
      @original_log_subscriber_logger = T.let(nil, T.untyped)
      @original_app_logger = T.let(nil, T.untyped)
      # The appenders add_appenders added. LogStruct replaces only these, and keeps any an app adds.
      @appenders = T.let([], T::Array[T.untyped])

      sig { returns(T::Boolean) }
      def self.configured?
        !@logger.nil?
      end

      # Configures SemanticLogger and replaces Rails' loggers with LogStruct's:
      # - the level from config.log_level (info in production, debug elsewhere)
      # - the appenders for the environment (see add_appenders)
      # - Rails.logger and the framework loggers (ActiveRecord, ActionController, ActiveJob, ...)
      #
      # @param app [Rails::Application] The Rails application instance
      sig { params(app: T.untyped).void }
      def self.configure_semantic_logger(app)
        # Set SemanticLogger configuration
        ::SemanticLogger.application = Rails.application.class.module_parent_name
        ::SemanticLogger.environment = Rails.env

        # Determine log level from Rails config
        log_level = determine_log_level(app)
        ::SemanticLogger.default_level = log_level

        # Add appropriate appenders based on environment
        remove_appenders
        add_appenders(app)
        ReopenAfterFork.install!

        # Replace Rails.logger with SemanticLogger
        replace_rails_logger(app)
      end

      # Adds the appenders again, with the settings config/initializers changed after the logger was set up
      # (prefer_json_in_development, enable_color_output, color_map, filter_noisy_loggers, local_environments).
      # Appenders the app added in config/initializers stay.
      sig { params(app: T.untyped).void }
      def self.reconfigure_appenders(app)
        remove_appenders
        add_appenders(app)
      end

      # Removes the appenders add_appenders added, after writing the lines already queued for them
      sig { void }
      def self.remove_appenders
        return if @appenders.empty?

        ::SemanticLogger.flush
        @appenders.each { |appender| ::SemanticLogger.remove_appender(appender) }
        @appenders = []
      end

      sig { params(app: T.untyped).returns(Symbol) }
      def self.determine_log_level(app)
        level = if app.config.log_level
          app.config.log_level
        elsif Rails.env.production?
          :info
        elsif Rails.env.test?
          :debug
        else
          :debug
        end
        # Rails config.log_level can be a String or Symbol
        level.is_a?(String) ? level.to_sym : level
      end

      sig { params(app: T.untyped).void }
      def self.add_appenders(app)
        config = LogStruct.config

        # Determine output destination
        io = determine_output(app)

        # Ruby buffers STDOUT when it isn't a terminal, so in a container lines waited until the buffer
        # filled or the process exited. (GoodJob's executable only syncs STDOUT when it writes its own
        # text logs there.)
        io.sync = true if io.equal?($stdout)

        appenders = []
        appenders << if Rails.env.development?
          if config.prefer_json_in_development
            # Default to production-style JSON in development when enabled
            ::SemanticLogger.add_appender(
              io: io,
              formatter: LogStruct::SemanticLogger::Formatter.new,
              filter: determine_filter
            )
          elsif config.enable_color_output
            # Opt-in colorful human formatter in development
            ::SemanticLogger.add_appender(
              io: io,
              formatter: LogStruct::SemanticLogger::ColorFormatter.new(
                color_map: config.color_map
              ),
              filter: determine_filter
            )
          else
            ::SemanticLogger.add_appender(
              io: io,
              formatter: LogStruct::SemanticLogger::Formatter.new,
              filter: determine_filter
            )
          end
        else
          # Use our custom JSON formatter in non-development environments
          ::SemanticLogger.add_appender(
            io: io,
            formatter: LogStruct::SemanticLogger::Formatter.new,
            filter: determine_filter
          )
        end

        # Log to Rails' log file too in development and test (config.local_environments), unless
        # RAILS_LOG_TO_STDOUT says not to. Production and other servers log to STDOUT only: nothing
        # rotates the file, and in a container it only fills the disk.
        local = config.local_environments.include?(Rails.env.to_sym)
        if local && app.config.paths["log"].first && ENV["RAILS_LOG_TO_STDOUT"].blank?
          appenders << ::SemanticLogger.add_appender(
            file_name: app.config.paths["log"].first,
            formatter: LogStruct::SemanticLogger::Formatter.new,
            filter: determine_filter
          )
        end
        # add_appender returns nil when it ignores a second STDOUT appender
        @appenders = appenders.compact
      end

      sig { params(app: T.untyped).returns(T.untyped) }
      def self.determine_output(app)
        # Always honor explicit STDOUT directive
        return $stdout if ENV["RAILS_LOG_TO_STDOUT"].present?

        if Rails.env.test?
          # Use StringIO in test to keep stdout clean
          StringIO.new
        else
          # Use STDOUT for app logs in dev/production
          $stdout
        end
      end

      sig { returns(T.nilable(Regexp)) }
      def self.determine_filter
        # Filter out noisy loggers if configured
        config = LogStruct.config
        return nil unless config.filter_noisy_loggers

        # Common noisy loggers to filter
        /\A(ActionView|ActionController::RoutingError|ActiveRecord::SchemaMigration)/
      end

      # Replaces Rails.logger, ActiveSupport::LogSubscriber.logger, config.logger and the framework
      # loggers (ActiveRecord, ActionController, ActionMailer, ActiveJob, ActionView, ActionCable)
      # with LogStruct's SemanticLogger logger, so every Rails line is a LogStruct JSON line
      #
      # @param app [Rails::Application] The Rails application instance
      sig { params(app: T.untyped).void }
      def self.replace_rails_logger(app)
        # Create new SemanticLogger instance
        logger = LogStruct::SemanticLogger::Logger.new("Rails")
        @logger = logger
        @original_rails_logger = Rails.logger
        @original_log_subscriber_logger = ActiveSupport::LogSubscriber.logger
        @original_app_logger = app.config.logger

        # Replace Rails.logger
        Rails.logger = logger

        # Rails assigns ActiveSupport::LogSubscriber.logger once during boot
        # (in the active_support.set_log_subscriber_logger initializer), so log
        # subscribers such as Lograge keep writing to the original boot logger
        # unless this reference is updated along with Rails.logger.
        ActiveSupport::LogSubscriber.logger = logger

        # Also replace the component loggers. Use load hooks rather than referencing the base
        # classes: loading them this early would apply their on_load hooks before the app's
        # initializers run, e.g. ActiveRecord would copy an empty filter_parameters into
        # filter_attributes.
        COMPONENT_LOAD_HOOKS.each do |hook|
          ActiveSupport.on_load(hook) { self.logger = logger }
        end

        # Store reference in app config
        app.config.logger = logger
      end

      # Puts back the loggers that replace_rails_logger replaced. Used when an initializer
      # disables LogStruct after the logger was replaced at boot.
      sig { params(app: T.untyped).void }
      def self.restore_rails_logger(app)
        logger = @logger
        return unless logger

        original_logger = @original_rails_logger
        Rails.logger = original_logger
        ActiveSupport::LogSubscriber.logger = @original_log_subscriber_logger
        app.config.logger = @original_app_logger
        remove_appenders

        # These hooks run after the ones that installed LogStruct's logger, including for
        # components that are already loaded
        COMPONENT_LOAD_HOOKS.each do |hook|
          ActiveSupport.on_load(hook) do
            self.logger = original_logger if self.logger.equal?(logger)
          end
        end

        @logger = nil
      end
    end
  end
end
