# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class LevelTest < ActiveSupport::TestCase
    def test_from_severity_with_string
      # Test conversion from string values
      assert_equal Level::Debug, Level.from_severity("debug")
      assert_equal Level::Info, Level.from_severity("info")
      assert_equal Level::Warn, Level.from_severity("warn")
      assert_equal Level::Error, Level.from_severity("error")
      assert_equal Level::Fatal, Level.from_severity("fatal")
      assert_equal Level::Unknown, Level.from_severity("unknown")

      # Test case-insensitivity
      assert_equal Level::Debug, Level.from_severity("DEBUG")
      assert_equal Level::Info, Level.from_severity("Info")

      # Test with invalid value
      assert_equal Level::Unknown, Level.from_severity("invalid")
    end

    def test_from_severity_with_symbol
      # Test conversion from symbol values
      assert_equal Level::Debug, Level.from_severity(:debug)
      assert_equal Level::Info, Level.from_severity(:info)
      assert_equal Level::Warn, Level.from_severity(:warn)
      assert_equal Level::Error, Level.from_severity(:error)
      assert_equal Level::Fatal, Level.from_severity(:fatal)
      assert_equal Level::Unknown, Level.from_severity(:unknown)
    end

    def test_from_severity_with_integer
      # Test conversion from standard Logger constants
      assert_equal Level::Debug, Level.from_severity(::Logger::DEBUG)
      assert_equal Level::Info, Level.from_severity(::Logger::INFO)
      assert_equal Level::Warn, Level.from_severity(::Logger::WARN)
      assert_equal Level::Error, Level.from_severity(::Logger::ERROR)
      assert_equal Level::Fatal, Level.from_severity(::Logger::FATAL)
      assert_equal Level::Unknown, Level.from_severity(::Logger::UNKNOWN)

      # Test with an invalid integer
      assert_equal Level::Unknown, Level.from_severity(99)
    end

    def test_from_severity_with_nil
      # Test with nil
      assert_equal Level::Unknown, Level.from_severity(nil)
    end

    def test_to_severity_int
      # Test conversion from Level to Logger constants
      assert_equal ::Logger::DEBUG, Level::Debug.to_severity_int
      assert_equal ::Logger::INFO, Level::Info.to_severity_int
      assert_equal ::Logger::WARN, Level::Warn.to_severity_int
      assert_equal ::Logger::ERROR, Level::Error.to_severity_int
      assert_equal ::Logger::FATAL, Level::Fatal.to_severity_int
      assert_equal ::Logger::UNKNOWN, Level::Unknown.to_severity_int
    end
  end
end
