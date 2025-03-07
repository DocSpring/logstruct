# typed: strict
# frozen_string_literal: true

require "logger"

module LogStruct
  # Define log levels as an enum
  class LogLevel < T::Enum
    extend T::Sig

    enums do
      # Standard log levels
      Debug = new(:debug)
      Info = new(:info)
      Warn = new(:warn)
      Error = new(:error)
      Fatal = new(:fatal)
      Unknown = new(:unknown)
    end

    # Convert a LogLevel to the corresponding Logger integer constant
    sig { returns(Integer) }
    def to_severity_int
      case serialize
      when :debug then ::Logger::DEBUG
      when :info then ::Logger::INFO
      when :warn then ::Logger::WARN
      when :error then ::Logger::ERROR
      when :fatal then ::Logger::FATAL
      else ::Logger::UNKNOWN
      end
    end

    # Convert a string or integer severity to a LogLevel
    sig { params(severity: T.any(String, Symbol, Integer, NilClass)).returns(LogLevel) }
    def self.from_severity(severity)
      return Unknown if severity.nil?
      return from_severity_int(severity) if severity.is_a?(Integer)
      from_severity_sym(severity.downcase.to_sym)
    end

    sig { params(severity: Symbol).returns(LogLevel) }
    def self.from_severity_sym(severity)
      case severity.to_s.downcase.to_sym
      when :debug then Debug
      when :info then Info
      when :warn then Warn
      when :error then Error
      when :fatal then Fatal
      else Unknown
      end
    end

    sig { params(severity: Integer).returns(LogLevel) }
    def self.from_severity_int(severity)
      case severity
      when ::Logger::DEBUG then Debug
      when ::Logger::INFO then Info
      when ::Logger::WARN then Warn
      when ::Logger::ERROR then Error
      when ::Logger::FATAL then Fatal
      else Unknown
      end
    end
  end
end
