# typed: strict
# frozen_string_literal: true

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
    
    # Convert a string or integer severity to a LogLevel
    sig { params(severity: T.any(String, Symbol, Integer, NilClass)).returns(LogLevel) }
    def self.from_severity(severity)
      return Unknown if severity.nil?
      
      # Convert integers to standard Logger level names
      if severity.is_a?(Integer)
        case severity
        when ::Logger::DEBUG then return Debug 
        when ::Logger::INFO then return Info
        when ::Logger::WARN then return Warn
        when ::Logger::ERROR then return Error
        when ::Logger::FATAL then return Fatal
        else return Unknown
        end
      end
      
      # Convert string/symbol to an enum value
      case severity.to_s.downcase.to_sym
      when :debug then Debug
      when :info then Info
      when :warn then Warn
      when :error then Error
      when :fatal then Fatal
      else Unknown
      end
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
  end
end
