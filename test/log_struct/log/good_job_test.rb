# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/log/good_job"

module LogStruct
  module Log
    class GoodJobTest < ActiveSupport::TestCase
      test "initializes Start with required fields" do
        log_entry = GoodJob::Start.new(
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36)
        )

        assert_equal Source::Job, log_entry.source
        assert_equal Event::Start, log_entry.event
        assert_equal Level::Info, log_entry.level
        assert_instance_of Time, log_entry.timestamp
      end

      test "accepts job identification fields" do
        log_entry = GoodJob::Start.new(
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: "default"
        )

        assert_equal "job_123", log_entry.job_id
        assert_equal "UserNotificationJob", log_entry.job_class
        assert_equal "default", log_entry.queue_name
      end

      test "accepts execution context fields" do
        scheduled_time = Time.now + 1.hour
        log_entry = GoodJob::Start.new(
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          arguments: ["user_123", {notify: true}],
          executions: 2,
          scheduled_at: scheduled_time
        )

        assert_equal ["user_123", {notify: true}], log_entry.arguments
        assert_equal 2, log_entry.executions
        assert_equal scheduled_time, log_entry.scheduled_at
      end

      test "accepts error information fields" do
        backtrace = ["file1.rb:10", "file2.rb:20"]
        log_entry = GoodJob::Error.new(
          level: Level::Error,
          err_class: "StandardError",
          error_message: "Job failed",
          backtrace: backtrace,
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36)
        )

        assert_equal Level::Error, log_entry.level
        assert_equal "StandardError", log_entry.err_class
        assert_equal "Job failed", log_entry.error_message
        assert_equal backtrace, log_entry.backtrace
      end

      test "accepts GoodJob-specific metadata" do
        log_entry = GoodJob::Schedule.new(
          scheduled_at: Time.now + 60,
          duration_ms: 10.0,
          priority: 10,
          cron_key: "daily_cleanup"
        )

        assert_equal 10, log_entry.priority
        assert_equal "daily_cleanup", log_entry.cron_key
      end

      test "accepts performance metrics" do
        finished_time = Time.now
        log_entry = GoodJob::Finish.new(
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          duration_ms: 2500.0,
          finished_at: finished_time
        )

        assert_in_delta(2500.0, log_entry.duration_ms)
        assert_equal finished_time, log_entry.finished_at
      end

      test "serializes to hash with all fields" do
        Time.now
        1.hour
        finished_time = Time.now

        log_entry = GoodJob::Finish.new(
          level: Level::Info,
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: "default",
          arguments: ["user_123"],
          executions: 1,
          process_id: 1234,
          thread_id: "thread_abc",
          duration_ms: 2500.0,
          finished_at: finished_time,
          additional_data: {custom_field: "value"}
        )

        hash = log_entry.serialize

        # Check common fields
        assert_equal "job", hash[:src]
        assert_equal "finish", hash[:evt]
        assert_equal "info", hash[:lvl]
        assert hash[:ts]

        # Check job identification
        assert_equal "job_123", hash[:job_id]
        assert_equal "UserNotificationJob", hash[:job_class]
        assert_equal "default", hash[:queue_name]
        # Removed batch_id and job_label fields from schema

        # Check execution context
        assert_equal ["user_123"], hash[:arguments]
        assert_equal 1, hash[:executions]
        refute hash.key?(:exception_executions)
        refute hash.key?(:scheduled_at)

        # Check GoodJob metadata
        assert_equal 1234, hash[:pid]
        assert_equal "thread_abc", hash[:tid]
        # Priority/cron_key only on Schedule events

        # Check performance metrics
        assert_in_delta(2500.0, hash[:duration_ms])
        assert_equal finished_time.iso8601, hash[:finished_at]

        # Check additional data
        assert_equal "value", hash[:custom_field]
      end

      test "serializes with only present fields" do
        log_entry = GoodJob::Log.new(
          message: "starting",
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          job_id: "job_123"
        )

        hash = log_entry.serialize

        # Should include present fields
        assert_equal "job", hash[:src]
        assert_equal "log", hash[:evt]
        assert_equal "job_123", hash[:job_id]

        # Should not include nil fields
        refute hash.key?(:job_class)
        refute hash.key?(:queue_name)
        refute hash.key?(:error_message)
        refute hash.key?(:finished_at)
      end

      test "handles all valid event types" do
        assert_equal Event::Log, GoodJob::Log.new(message: "m", process_id: 1, thread_id: "t").event
        assert_equal Event::Enqueue, GoodJob::Enqueue.new(duration_ms: 1.0).event
        assert_equal Event::Start, GoodJob::Start.new(process_id: 1, thread_id: "t").event
        assert_equal Event::Finish, GoodJob::Finish.new(process_id: 1, thread_id: "t", duration_ms: 1.0, finished_at: Time.now).event
        assert_equal Event::Error, GoodJob::Error.new(process_id: 1, thread_id: "t", err_class: "E", error_message: "m").event
        assert_equal Event::Schedule, GoodJob::Schedule.new(duration_ms: 1.0, scheduled_at: Time.now).event
      end

      test "additional_data field works correctly" do
        log_entry = GoodJob::Log.new(
          message: "m",
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          additional_data: {
            user_id: 123,
            request_id: "req_abc",
            custom_metric: 42.5
          }
        )

        hash = log_entry.serialize

        assert_equal 123, hash[:user_id]
        assert_equal "req_abc", hash[:request_id]
        assert_in_delta(42.5, hash[:custom_metric])
      end

      test "timestamp is automatically set" do
        before_time = Time.now
        log_entry = GoodJob::Enqueue.new(duration_ms: 1.0)
        after_time = Time.now

        assert_operator log_entry.timestamp, :>=, before_time
        assert_operator log_entry.timestamp, :<=, after_time
      end

      test "includes proper interfaces" do
        klass = GoodJob::Start

        assert_includes klass.included_modules, Interfaces::CommonFields
        assert_includes klass.included_modules, Interfaces::AdditionalDataField
        assert_includes klass.included_modules, SerializeCommon
        assert_includes klass.included_modules, MergeAdditionalDataFields
      end
    end
  end
end
