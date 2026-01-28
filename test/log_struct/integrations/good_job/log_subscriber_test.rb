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
          @log_output = setup_isolated_logger
          Rails.logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
          @subscriber = LogSubscriber.new
        end

        teardown do
          Rails.logger = @original_logger
          teardown_isolated_logger
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
          clear_log_buffer(@log_output)

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
          assert_in_delta(100.0, log["duration_ms"])
        end

        test "start event creates proper log entry" do
          clear_log_buffer(@log_output)

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
          assert_in_delta(500.0, log["wait_ms"])
          assert_equal Process.pid, log["pid"]
          assert log["tid"]
        end

        test "finish event creates proper log entry" do
          clear_log_buffer(@log_output)

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
          assert_in_delta(2500.0, log["duration_ms"])
          assert log["finished_at"]
          assert_equal "success", log["result"]
        end

        test "converts monotonic event times to wall clock" do
          clear_log_buffer(@log_output)

          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          finish_time = start_time + 0.25
          event_data = create_test_event({
            job: create_mock_job("CompletedJob", "job_789", "default"),
            execution: create_mock_execution(executions: 1),
            duration: 0.25,
            result: "success"
          },
            start_time: start_time,
            finish_time: finish_time)

          @subscriber.finish(event_data)
          ::SemanticLogger.flush

          output = @log_output.string
          log = JSON.parse(output.lines.first.strip)

          now = ::Time.now
          ts = ::Time.iso8601(log["ts"])
          finished_at = ::Time.iso8601(log["finished_at"])

          assert_in_delta now.to_f, ts.to_f, 5.0
          assert_in_delta now.to_f, finished_at.to_f, 5.0
        end

        test "error event creates proper log entry" do
          clear_log_buffer(@log_output)

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
          assert_equal "StandardError", log["error_class"]
          assert_equal "Job processing failed", log["error_message"]
          assert_equal ["file1.rb:10", "file2.rb:20", "file3.rb:30"], log["backtrace"]
          assert_in_delta(1200.0, log["duration_ms"])
        end

        test "schedule event creates proper log entry" do
          clear_log_buffer(@log_output)

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
          assert_in_delta(50.0, log["duration_ms"])
        end

        test "handles missing job data gracefully" do
          clear_log_buffer(@log_output)

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
          clear_log_buffer(@log_output)

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

          # Should limit backtrace to 5 lines (done in Error#to_h)
          assert_equal 5, log["backtrace"].length
          assert_equal "file1.rb:1", log["backtrace"].first
          assert_equal "file5.rb:5", log["backtrace"].last
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

        def create_test_event(payload_data, start_time: nil, finish_time: nil)
          duration = payload_data[:duration] || 0.0
          start = start_time || Time.now.to_f
          finish = finish_time || start + duration
          ActiveSupport::Notifications::Event.new(
            "good_job.test",
            start,
            finish,
            "test",
            payload_data
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
