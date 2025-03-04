# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class LogLevelTest < ActiveSupport::TestCase
    def test_from_severity_with_string
      # Test conversion from string values
      assert_equal LogLevel::Debug, LogLevel.from_severity("debug")
      assert_equal LogLevel::Info, LogLevel.from_severity("info")
      assert_equal LogLevel::Warn, LogLevel.from_severity("warn")
      assert_equal LogLevel::Error, LogLevel.from_severity("error")
      assert_equal LogLevel::Fatal, LogLevel.from_severity("fatal")
      assert_equal LogLevel::Unknown, LogLevel.from_severity("unknown")
      
      # Test case-insensitivity
      assert_equal LogLevel::Debug, LogLevel.from_severity("DEBUG")
      assert_equal LogLevel::Info, LogLevel.from_severity("Info")
      
      # Test with invalid value
      assert_equal LogLevel::Unknown, LogLevel.from_severity("invalid")
    end
    
    def test_from_severity_with_symbol
      # Test conversion from symbol values
      assert_equal LogLevel::Debug, LogLevel.from_severity(:debug)
      assert_equal LogLevel::Info, LogLevel.from_severity(:info)
      assert_equal LogLevel::Warn, LogLevel.from_severity(:warn)
      assert_equal LogLevel::Error, LogLevel.from_severity(:error)
      assert_equal LogLevel::Fatal, LogLevel.from_severity(:fatal)
      assert_equal LogLevel::Unknown, LogLevel.from_severity(:unknown)
    end
    
    def test_from_severity_with_integer
      # Test conversion from standard Logger constants
      assert_equal LogLevel::Debug, LogLevel.from_severity(::Logger::DEBUG)
      assert_equal LogLevel::Info, LogLevel.from_severity(::Logger::INFO)
      assert_equal LogLevel::Warn, LogLevel.from_severity(::Logger::WARN)
      assert_equal LogLevel::Error, LogLevel.from_severity(::Logger::ERROR)
      assert_equal LogLevel::Fatal, LogLevel.from_severity(::Logger::FATAL)
      assert_equal LogLevel::Unknown, LogLevel.from_severity(::Logger::UNKNOWN)
      
      # Test with an invalid integer
      assert_equal LogLevel::Unknown, LogLevel.from_severity(99)
    end
    
    def test_from_severity_with_nil
      # Test with nil
      assert_equal LogLevel::Unknown, LogLevel.from_severity(nil)
    end
    
    def test_to_severity_int
      # Test conversion from LogLevel to Logger constants
      assert_equal ::Logger::DEBUG, LogLevel::Debug.to_severity_int
      assert_equal ::Logger::INFO, LogLevel::Info.to_severity_int
      assert_equal ::Logger::WARN, LogLevel::Warn.to_severity_int
      assert_equal ::Logger::ERROR, LogLevel::Error.to_severity_int
      assert_equal ::Logger::FATAL, LogLevel::Fatal.to_severity_int
      assert_equal ::Logger::UNKNOWN, LogLevel::Unknown.to_severity_int
    end
  end
end