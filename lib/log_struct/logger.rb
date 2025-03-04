# typed: strict
# frozen_string_literal: true

require "logger"
require_relative "formatter"
require_relative "log_level"

module LogStruct
  # Base Logger class that uses LogStruct::Formatter
  # Inherits from Ruby's standard Logger
  class Logger < ::Logger
    extend T::Sig

    sig { params(logdev: T.any(String, IO), shift_age: T.nilable(Integer), shift_size: T.nilable(Integer)).void }
    def initialize(logdev = $stdout, shift_age = 0, shift_size = 1048576)
      super
      self.formatter = LogStruct::Formatter.new
    end

    # Override add to ensure proper log level handling
    sig { params(severity: T.any(String, Integer), message: T.nilable(T.untyped), progname: T.nilable(String)).returns(T.untyped) }
    def add(severity, message = nil, progname = nil)
      severity = severity.to_s.upcase if severity.is_a?(Integer)
      return true if severity.nil? || (@level && @level > LogStruct::LogLevel.from_string(severity))

      # Let subclasses process the message by overriding process_log_data
      log_data = process_log_data(severity, message, progname)
      
      # Pass to formatter
      super(severity, nil, log_data)
    end

    protected

    # Process log data before sending to formatter
    # Subclasses should override this to format specific log types
    sig { params(severity: String, message: T.nilable(T.untyped), progname: T.nilable(String)).returns(T.untyped) }
    def process_log_data(severity, message, progname)
      # Default implementation returns message as is
      message || progname
    end
  end
end