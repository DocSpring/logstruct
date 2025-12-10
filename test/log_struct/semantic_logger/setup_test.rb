# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/semantic_logger/setup"

module LogStruct
  module SemanticLogger
    class SetupTest < ActiveSupport::TestCase
      test "skips file appender when RAILS_LOG_TO_STDOUT is set" do
        # Mock app with log path configured
        app = Minitest::Mock.new
        config = Minitest::Mock.new
        paths = {"log" => ["/tmp/test.log"]}

        app.expect(:config, config)
        app.expect(:config, config)
        config.expect(:paths, paths)
        config.expect(:log_level, :info)

        # Set RAILS_LOG_TO_STDOUT
        original_env = ENV["RAILS_LOG_TO_STDOUT"]
        ENV["RAILS_LOG_TO_STDOUT"] = "true"

        # Clear appenders and track what gets added
        ::SemanticLogger.clear_appenders!
        appenders_before = ::SemanticLogger.appenders.dup

        begin
          Setup.add_appenders(app)

          # Should only have IO appender, not file appender
          appenders = ::SemanticLogger.appenders.to_a
          io_appenders = appenders.select { |a| a.is_a?(::SemanticLogger::Appender::IO) }
          file_appenders = appenders.select { |a| a.is_a?(::SemanticLogger::Appender::File) }

          assert_equal 1, io_appenders.length, "Should have exactly one IO appender"
          assert_equal 0, file_appenders.length, "Should have no file appenders when RAILS_LOG_TO_STDOUT is set"
        ensure
          ENV["RAILS_LOG_TO_STDOUT"] = original_env
          # Restore appenders
          ::SemanticLogger.clear_appenders!
          appenders_before.each { |a| ::SemanticLogger.appenders << a }
        end
      end

      test "adds file appender when RAILS_LOG_TO_STDOUT is not set" do
        # Mock app with log path configured
        app = Minitest::Mock.new
        config = Minitest::Mock.new
        paths = {"log" => ["/tmp/test.log"]}

        app.expect(:config, config)
        app.expect(:config, config)
        app.expect(:config, config)
        config.expect(:paths, paths)
        config.expect(:paths, paths)
        config.expect(:log_level, :info)

        # Ensure RAILS_LOG_TO_STDOUT is not set
        original_env = ENV["RAILS_LOG_TO_STDOUT"]
        ENV.delete("RAILS_LOG_TO_STDOUT")

        # Clear appenders and track what gets added
        ::SemanticLogger.clear_appenders!
        appenders_before = ::SemanticLogger.appenders.dup

        begin
          Setup.add_appenders(app)

          # Should have both IO and file appenders
          appenders = ::SemanticLogger.appenders.to_a
          io_appenders = appenders.select { |a| a.is_a?(::SemanticLogger::Appender::IO) }
          file_appenders = appenders.select { |a| a.is_a?(::SemanticLogger::Appender::File) }

          assert_equal 1, io_appenders.length, "Should have exactly one IO appender"
          assert_equal 1, file_appenders.length, "Should have exactly one file appender when RAILS_LOG_TO_STDOUT is not set"
        ensure
          ENV["RAILS_LOG_TO_STDOUT"] = original_env if original_env
          # Restore appenders
          ::SemanticLogger.clear_appenders!
          appenders_before.each { |a| ::SemanticLogger.appenders << a }
        end
      end
    end
  end
end
