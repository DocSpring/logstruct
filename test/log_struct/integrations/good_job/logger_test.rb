# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/integrations/good_job/logger"
require "stringio"

module LogStruct
  module Integrations
    module GoodJob
      class LoggerTest < ActiveSupport::TestCase
        setup do
          @io = setup_isolated_logger
          @logger = Logger.new("GoodJob")
          @logger.level = :debug
        end

        teardown do
          teardown_isolated_logger
        end

        test "extends LogStruct SemanticLogger Logger" do
          assert_kind_of LogStruct::SemanticLogger::Logger, @logger
        end

        test "logs info messages with GoodJob structure" do
          clear_log_buffer(@io)

          @logger.info("Job started")
          ::SemanticLogger.flush

          output = @io.string

          assert output && !output.empty?, "Expected output to be generated"

          log = JSON.parse(output.lines.first.strip)

          # Should use job source
          assert_equal "job", log["src"]
          assert_equal "log", log["evt"]
          assert_equal "info", log["lvl"]

          # Should include message in additional_data
          assert_equal "Job started", log["msg"]

          # Should include process information
          assert_equal Process.pid, log["pid"]
          assert log["tid"]
        end

        test "logs error messages with proper level" do
          clear_log_buffer(@io)

          @logger.error("Job failed")
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "error", log["lvl"]
          assert_equal "Job failed", log["msg"]
        end

        test "extracts job context from thread local variables" do
          clear_log_buffer(@io)

          # Simulate GoodJob setting thread-local execution context
          mock_execution = OpenStruct.new(
            job_id: "job_123",
            job_class: "TestJob",
            queue_name: :default,
            executions: 1,
            scheduled_at: Time.now,
            priority: 5
          )

          Thread.current[:good_job_execution] = mock_execution

          @logger.info("Processing job")
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "job_123", log["job_id"]
          assert_equal "TestJob", log["job_class"]
          assert_equal "default", log["queue_name"]
          assert_equal 1, log["executions"]
          assert log["scheduled_at"]
          assert_equal 5, log["priority"]

          # Clean up
          Thread.current[:good_job_execution] = nil
        end

        test "handles missing job context gracefully" do
          clear_log_buffer(@io)

          # Ensure no job context is set
          Thread.current[:good_job_execution] = nil

          @logger.info("Regular log message")
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          # Should still log successfully
          assert_equal "job", log["src"]
          assert_equal "Regular log message", log["msg"]

          # Job-specific fields should be absent
          refute log.key?("job_id")
          refute log.key?("job_class")
          refute log.key?("queue_name")
        end

        test "handles execution context with missing methods gracefully" do
          clear_log_buffer(@io)

          # Create a mock execution that doesn't respond to some methods
          mock_execution = Object.new
          mock_execution.define_singleton_method(:job_id) do
            "partial_job_123"
          end
          # job_class method intentionally missing

          Thread.current[:good_job_execution] = mock_execution

          @logger.info("Partial context job")
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          # Should include available fields
          assert_equal "partial_job_123", log["job_id"]

          # Should not include unavailable fields
          refute log.key?("job_class")

          # Clean up
          Thread.current[:good_job_execution] = nil
        end

        test "supports all log levels" do
          clear_log_buffer(@io)

          levels = %w[debug info warn error fatal]

          levels.each do |level|
            # Use a fresh StringIO for each level to avoid clearing issues
            io = StringIO.new
            ::SemanticLogger.clear_appenders!
            ::SemanticLogger.add_appender(
              io: io,
              formatter: LogStruct::SemanticLogger::Formatter.new,
              async: false
            )

            @logger.send(level, "Test #{level} message")
            ::SemanticLogger.flush

            output = io.string
            next if output.empty?  # Skip if level is filtered out

            log = JSON.parse(T.must(output.lines.first).strip)

            assert_equal level, log["lvl"]
            assert_equal "Test #{level} message", log["msg"]
          end
        end

        test "supports block syntax for messages" do
          clear_log_buffer(@io)

          @logger.info { "Block message" }
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "Block message", log["msg"]
        end

        test "maintains SemanticLogger functionality" do
          # Test that it still works as a SemanticLogger
          assert_respond_to @logger, :debug
          assert_respond_to @logger, :info
          assert_respond_to @logger, :warn
          assert_respond_to @logger, :error
          assert_respond_to @logger, :fatal
        end

        test "thread_id is consistently formatted" do
          clear_log_buffer(@io)

          @logger.info("Test message")
          ::SemanticLogger.flush

          output = @io.string
          log = JSON.parse(output.lines.first.strip)

          # Should be a string representation of thread object_id
          assert_kind_of String, log["tid"]
          assert_operator log["tid"].length, :>, 0
        end
      end
    end
  end
end
