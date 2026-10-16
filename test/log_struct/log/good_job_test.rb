# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/log/good_job"

module LogStruct
  module Log
    class GoodJobTest < ActiveSupport::TestCase
      test "initializes Log with required fields" do
        log_entry = GoodJob::Log.new(
          message: "starting",
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36)
        )

        assert_equal Source::Job, log_entry.source
        assert_equal Event::Log, log_entry.event
        assert_equal Level::Info, log_entry.level
        assert_instance_of Time, log_entry.timestamp
      end

      test "accepts job identification fields" do
        log_entry = GoodJob::Log.new(
          message: "m",
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: :default
        )

        assert_equal "job_123", log_entry.job_id
        assert_equal "UserNotificationJob", log_entry.job_class
        assert_equal :default, log_entry.queue_name
      end

      test "accepts execution context fields" do
        scheduled_time = Time.now + 1.hour
        log_entry = GoodJob::Log.new(
          message: "m",
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
          error_class: "StandardError",
          error_message: "Job failed",
          backtrace: backtrace,
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36)
        )

        assert_equal Level::Error, log_entry.level
        assert_equal "StandardError", log_entry.error_class
        assert_equal "Job failed", log_entry.error_message
        assert_equal backtrace, log_entry.backtrace
      end

      test "serializes an error with all fields" do
        log_entry = GoodJob::Error.new(
          level: Level::Error,
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: :default,
          arguments: ["user_123"],
          executions: 1,
          process_id: 1234,
          thread_id: "thread_abc",
          error_class: "RuntimeError",
          error_message: "boom",
          duration_ms: 2500.0,
          exception_executions: 3
        )

        hash = log_entry.serialize

        assert_equal "job", hash[:src]
        assert_equal "error", hash[:evt]
        assert_equal "error", hash[:lvl]
        assert hash[:ts]
        assert_equal "job_123", hash[:job_id]
        assert_equal "UserNotificationJob", hash[:job_class]
        assert_equal :default, hash[:queue_name]
        assert_equal ["user_123"], hash[:arguments]
        assert_equal 1, hash[:executions]
        assert_equal 3, hash[:exception_executions]
        assert_equal 1234, hash[:pid]
        assert_equal "thread_abc", hash[:tid]
        assert_in_delta(2500.0, hash[:duration_ms])
        assert_equal "RuntimeError", hash[:error_class]
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
        refute hash.key?(:scheduled_at)
      end

      test "handles all valid event types" do
        assert_equal Event::Log, GoodJob::Log.new(message: "m", process_id: 1, thread_id: "t").event
        assert_equal Event::Error, GoodJob::Error.new(process_id: 1, thread_id: "t", error_class: "E", error_message: "m").event
        refute defined?(GoodJob::Enqueue), "GoodJob jobs' enqueue, start and finish lines come from the ActiveJob integration"
      end

      test "scheduled_at and priority fields work correctly" do
        scheduled_time = Time.now
        log_entry = GoodJob::Log.new(
          message: "m",
          process_id: Process.pid,
          thread_id: Thread.current.object_id.to_s(36),
          scheduled_at: scheduled_time,
          priority: 10
        )

        hash = log_entry.serialize

        assert_equal scheduled_time.iso8601, hash[:scheduled_at]
        assert_equal 10, hash[:priority]
      end

      test "timestamp is automatically set" do
        before_time = Time.now
        log_entry = GoodJob::Log.new(message: "m", process_id: 1, thread_id: "t")
        after_time = Time.now

        assert_operator log_entry.timestamp, :>=, before_time
        assert_operator log_entry.timestamp, :<=, after_time
      end

      test "includes proper interfaces" do
        klass = GoodJob::Log

        assert_includes klass.included_modules, Interfaces::CommonFields
        assert_includes klass.included_modules, Shared::SerializeCommon
      end
    end
  end
end
