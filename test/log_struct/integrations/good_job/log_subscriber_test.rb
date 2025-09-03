# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/integrations/good_job/log_subscriber"
require "active_support/notifications"
require "stringio"

module LogStruct
  module Integrations
    module GoodJob
      class LogSubscriberTest < ActiveSupport::TestCase
        setup do
          @original_logger = Rails.logger
          @log_output = StringIO.new

          # Set up a test logger
          test_logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
          ::SemanticLogger.clear_appenders!
          ::SemanticLogger.add_appender(
            io: @log_output,
            formatter: LogStruct::SemanticLogger::Formatter.new,
            async: false
          )
          Rails.logger = test_logger

          @subscriber = LogSubscriber.new
        end

        teardown do
          Rails.logger = @original_logger
          ::SemanticLogger.clear_appenders!
        end

        test "extends ActiveSupport LogSubscriber" do
          assert_kind_of ::ActiveSupport::LogSubscriber, @subscriber
        end

        test "responds to job event methods" do
          assert_respond_to @subscriber, :enqueue
          assert_respond_to @subscriber, :start
          assert_respond_to @subscriber, :finish
          assert_respond_to @subscriber, :error
          assert_respond_to @subscriber, :schedule
        end

        test "enqueue event creates proper log entry" do
          event_data = create_test_event({
            job: create_mock_job("UserNotificationJob", "job_123", "default"),
            duration: 0.1
          })

          @subscriber.enqueue(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "job", log["src"]
          assert_equal "enqueue", log["evt"]
          assert_equal "info", log["lvl"]
          assert_equal "job_123", log["job_id"]
          assert_equal "UserNotificationJob", log["job_class"]
          assert_equal "default", log["queue_name"]
          assert_in_delta(0.1, log["execution_time"])
        end

        test "start event creates proper log entry" do
          event_data = create_test_event({
            job: create_mock_job("TestJob", "job_456", "priority"),
            execution: create_mock_execution(executions: 1, wait_time: 0.5)
          })

          @subscriber.start(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "start", log["evt"]
          assert_equal "job_456", log["job_id"]
          assert_equal "TestJob", log["job_class"]
          assert_equal "priority", log["queue_name"]
          assert_equal 1, log["executions"]
          assert_in_delta(0.5, log["wait_time"])
          assert_equal Process.pid, log["pid"]
          assert log["tid"]
        end

        test "finish event creates proper log entry" do
          event_data = create_test_event({
            job: create_mock_job("CompletedJob", "job_789", "default"),
            execution: create_mock_execution(executions: 1),
            duration: 2.5,
            result: "success"
          })

          @subscriber.finish(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "finish", log["evt"]
          assert_equal "job_789", log["job_id"]
          assert_equal "CompletedJob", log["job_class"]
          assert_equal 1, log["executions"]
          assert_in_delta(2.5, log["run_time"])
          assert log["finished_at"]
          assert_equal "success", log["result"]
        end

        test "error event creates proper log entry" do
          exception = StandardError.new("Job processing failed")
          exception.set_backtrace(["file1.rb:10", "file2.rb:20", "file3.rb:30"])

          event_data = create_test_event({
            job: create_mock_job("FailedJob", "job_error", "critical"),
            execution: create_mock_execution(executions: 2, exception_executions: 1),
            exception: exception,
            duration: 1.2
          })

          @subscriber.error(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "error", log["evt"]
          assert_equal "error", log["lvl"]
          assert_equal "job_error", log["job_id"]
          assert_equal "FailedJob", log["job_class"]
          assert_equal 2, log["executions"]
          assert_equal 1, log["exception_executions"]
          assert_equal "StandardError", log["err_class"]
          assert_equal "Job processing failed", log["error_message"]
          assert_equal ["file1.rb:10", "file2.rb:20", "file3.rb:30"], log["backtrace"]
          assert_in_delta(1.2, log["run_time"])
        end

        test "schedule event creates proper log entry" do
          scheduled_time = Time.now + 1.hour
          event_data = create_test_event({
            job: create_mock_job("ScheduledJob",
              "job_scheduled",
              "later",
              {
                scheduled_at: scheduled_time,
                priority: 10,
                cron_key: "daily_cleanup"
              }),
            duration: 0.05
          })

          @subscriber.schedule(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          assert_equal "schedule", log["evt"]
          assert_equal "job_scheduled", log["job_id"]
          assert_equal "ScheduledJob", log["job_class"]
          assert_equal "later", log["queue_name"]
          assert_equal scheduled_time.iso8601, log["scheduled_at"]
          assert_equal 10, log["priority"]
          assert_equal "daily_cleanup", log["cron_key"]
          assert_in_delta(0.05, log["execution_time"])
        end

        test "handles missing job data gracefully" do
          # Event with minimal data
          event_data = create_test_event({})

          @subscriber.enqueue(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          # Should still create a valid log entry
          assert_equal "enqueue", log["evt"]
          assert_equal "job", log["src"]

          # Missing fields should not be present
          refute log.key?("job_id")
          refute log.key?("job_class")
        end

        test "truncates long backtraces" do
          exception = StandardError.new("Test error")
          # Create a very long backtrace (more than 20 lines)
          long_backtrace = (1..30).map { |i| "file#{i}.rb:#{i}" }
          exception.set_backtrace(long_backtrace)

          event_data = create_test_event({
            job: create_mock_job("TestJob", "job_123", "default"),
            exception: exception
          })

          @subscriber.error(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          # Should limit backtrace to 20 lines
          assert_equal 20, log["backtrace"].length
          assert_equal "file1.rb:1", log["backtrace"].first
          assert_equal "file20.rb:20", log["backtrace"].last
        end

        test "calculates wait_time correctly" do
          created_at = Time.now - 5.0  # 5 seconds ago
          performed_at = Time.now

          execution = create_mock_execution({
            created_at: created_at,
            performed_at: performed_at
          })

          wait_time = @subscriber.send(:calculate_wait_time, execution)

          assert_in_delta 5.0, wait_time, 0.1  # Allow small timing differences
        end

        test "handles missing timestamps in wait_time calculation" do
          # Execution without timestamps
          execution = create_mock_execution({created_at: nil, performed_at: nil})

          wait_time = @subscriber.send(:calculate_wait_time, execution)

          assert_nil wait_time
        end

        private

        def create_test_event(payload_data)
          OpenStruct.new(
            payload: payload_data,
            duration: payload_data[:duration] || 0.0
          )
        end

        def create_mock_job(job_class, job_id, queue_name, extra_attributes = {})
          OpenStruct.new({
            job_class: job_class,
            job_id: job_id,
            queue_name: queue_name,
            arguments: ["arg1", "arg2"],
            priority: 0,
            scheduled_at: nil,
            enqueue_caller_location: nil
          }.merge(extra_attributes))
        end

        def create_mock_execution(attributes = {})
          OpenStruct.new({
            executions: 1,
            exception_executions: 0,
            created_at: Time.now - 1,
            performed_at: Time.now,
            batch_id: nil,
            cron_key: nil
          }.merge(attributes))
        end
      end
    end
  end
end
