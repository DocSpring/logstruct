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

        # Stands in for GoodJob::CurrentThread (GoodJob isn't installed for the tests)
        def with_good_job_current_thread(**accessors)
          current_thread = Module.new
          accessors.each { |name, value| current_thread.define_singleton_method(name) { value } }
          good_job = Module.new
          good_job.const_set(:CurrentThread, current_thread)
          Object.const_set(:GoodJob, good_job)
          yield
        ensure
          Object.send(:remove_const, :GoodJob) if Object.const_defined?(:GoodJob, false)
        end

        test "extends LogStruct SemanticLogger Logger" do
          assert_kind_of LogStruct::SemanticLogger::Logger, @logger
        end

        test "logs a message with an exception, as SemanticLogger's loggers take them" do
          clear_log_buffer(@io)
          error = RuntimeError.new("boom")

          @logger.error("Notifier errored", nil, error)
          @logger.error("Notifier errored", error)
          ::SemanticLogger.flush

          lines = @io.string.lines.map { |line| JSON.parse(line) }

          assert_equal [%w[Notifier\ errored RuntimeError boom]] * 2,
            lines.map { |line| line.values_at("msg", "error_class", "error_message") }
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

        test "logs a LogStruct log entry as it is" do
          clear_log_buffer(@io)

          @logger.error(
            Log::GoodJob::Error.new(
              error_class: "RuntimeError",
              error_message: "boom",
              level: Level::Error,
              process_id: Process.pid,
              thread_id: "abc"
            )
          )
          @logger.info({evt: "custom", note: "hash"})
          ::SemanticLogger.flush

          lines = @io.string.lines.map { |line| JSON.parse(line) }

          assert_equal 2, lines.length
          assert_equal %w[error error RuntimeError boom], lines[0].values_at("evt", "lvl", "error_class", "error_message")
          assert_equal %w[custom hash], lines[1].values_at("evt", "note")
        end

        # GoodJob 4: CurrentThread.job is the GoodJob::Job being run
        test "logs the running job's fields from GoodJob::CurrentThread.job" do
          clear_log_buffer(@io)
          job = Struct.new(:active_job_id, :job_class, :queue_name, :executions_count, :scheduled_at, :priority, keyword_init: true).new(
            active_job_id: "job_123", job_class: "TestJob", queue_name: "default", executions_count: 1, scheduled_at: Time.now, priority: 5
          )

          with_good_job_current_thread(job: job) { @logger.info("Processing job") }
          ::SemanticLogger.flush
          log = JSON.parse(@io.string.lines.first.strip)

          assert_equal ["job_123", "TestJob", "default", 1, 5], log.values_at("job_id", "job_class", "queue_name", "executions", "priority")
          assert log["scheduled_at"]
        end

        # GoodJob 3: CurrentThread.execution, with the job class in its serialized params
        test "logs the running job's fields from GoodJob::CurrentThread.execution" do
          clear_log_buffer(@io)
          execution = Struct.new(:active_job_id, :serialized_params, :queue_name, keyword_init: true).new(
            active_job_id: "job_456", serialized_params: {"job_class" => "OlderJob"}, queue_name: "low"
          )

          with_good_job_current_thread(execution: execution) { @logger.info("Processing job") }
          ::SemanticLogger.flush
          log = JSON.parse(@io.string.lines.first.strip)

          assert_equal %w[job_456 OlderJob low], log.values_at("job_id", "job_class", "queue_name")
          refute log.key?("priority")
        end

        test "logs no job fields outside a job" do
          clear_log_buffer(@io)

          with_good_job_current_thread(job: nil) { @logger.info("Regular log message") }
          @logger.info("Without GoodJob")
          ::SemanticLogger.flush
          logs = @io.string.lines.map { |line| JSON.parse(line) }

          assert_equal ["Regular log message", "Without GoodJob"], logs.map { |log| log["msg"] }
          logs.each do |log|
            assert_equal "job", log["src"]
            refute log.key?("job_id")
            refute log.key?("job_class")
            refute log.key?("queue_name")
          end
        end

        test "supports all log levels" do
          clear_log_buffer(@io)

          levels = %w[debug info warn error fatal]

          levels.each do |level|
            # Use a fresh StringIO for each level to avoid clearing issues
            io = StringIO.new
            clear_test_appenders
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
