# typed: strict
# frozen_string_literal: true

require "active_support/logger"
require_relative "formatter"
require_relative "log_level"

module LogStruct
  # Base Logger class that uses LogStruct::Formatter
  # Inherits from ActiveSupport::Logger for Rails compatibility
  class Logger < ActiveSupport::Logger
    extend T::Sig

    # Initialize with the same parameters as ActiveSupport::Logger
    sig { params(logdev: T.any(String, IO, NilClass), shift_age: T.nilable(Integer), shift_size: T.nilable(Integer), level: T.nilable(T.any(Integer, Symbol, String))).void }
    def initialize(logdev = nil, shift_age = 0, shift_size = 1048576, level: nil)
      super
      self.formatter = LogStruct::Formatter.new

      # Set level explicitly if passed
      self.level = level if level
    end

    # Override add to ensure proper log level handling
    sig { params(severity: T.any(String, Integer), message: T.untyped, progname: T.nilable(String), block: T.nilable(T.proc.returns(T.untyped))).returns(T.untyped) }
    def add(severity, message = nil, progname = nil, &block)
      # Get the numeric severity level for comparison
      level_enum = LogLevel.from_severity(severity)
      severity_int = level_enum.to_severity_int
      
      return true if (@level && @level > severity_int)

      # Get message from block if block is given
      if block
        message = yield
      end

      # Let subclasses process the message by overriding process_log_data
      log_data = process_log_data(severity, message, progname)

      # Pass to formatter
      super(severity, nil, log_data)
    end

    protected

    # Process log data before sending to formatter
    # Subclasses should override this to format specific log types
    sig { params(severity: T.any(String, Integer), message: T.untyped, progname: T.nilable(String)).returns(T.untyped) }
    def process_log_data(severity, message, progname)
      # Default implementation returns message as is
      message || progname
    end
  end
end
