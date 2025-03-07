# typed: strict
# frozen_string_literal: true

module LogStruct
  # Utility functions for working with loggers
  module LoggerUtils
    extend T::Sig

    # Get the appropriate log target (device) from an existing logger
    # Falls back to Rails.logger or stdout if available
    sig { params(original_logger: T.nilable(T.any(Logger, ::Logger))).returns(T.any(String, IO, StringIO)) }
    def self.determine_log_target(original_logger = nil)
      if original_logger&.respond_to?(:instance_variable_get) &&
          (logger_dev = original_logger.instance_variable_get(:@logdev))
        # Extract device from original logger
        logger_dev.dev
      elsif (logger_dev = ::Rails.logger.instance_variable_get(:@logdev))
        # If we can't get from original, use Rails logger
        logger_dev.dev
      elsif ENV["RAILS_LOG_TO_STDOUT"].present?
        # Check for the Rails stdout environment variable
        $stdout
      elsif ::Rails.env.test?
        # Use the environment log file for test by default
        Rails.root.join("log", "#{::Rails.env}.log").to_s
      else
        # Default to stdout for other environments
        $stdout
      end
    end

    # Extract the log level from an existing logger
    # Falls back to Rails.logger or INFO if available
    sig { params(original_logger: T.nilable(T.any(Logger, ::Logger))).returns(T.any(Integer, Symbol, String)) }
    def self.determine_log_level(original_logger = nil)
      # Use original logger's level if possible
      return original_logger.level if original_logger&.respond_to?(:level)

      ::Rails.logger.level
    end

    # Create a new LogStruct logger with appropriate logger class
    # that inherits settings from an existing logger or Rails environment
    sig do
      params(
        logger_class: T.class_of(LogStruct::Logger),
        original_logger: T.nilable(Logger),
        options: T::Hash[Symbol, T.untyped]
      ).returns(LogStruct::Logger)
    end
    def self.create_logger(logger_class, original_logger: nil, options: {})
      # Extract options or fall back to determined values
      log_target = options.key?(:logdev) ? options[:logdev] : determine_log_target(original_logger)
      log_level = options.key?(:level) ? options[:level] : determine_log_level(original_logger)

      # Create the logger with the correct parameters
      logger_class.new(log_target, level: log_level)
    end
  end
end
