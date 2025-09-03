# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/log/good_job"

module LogStruct
  module Log
    class GoodJobTest < ActiveSupport::TestCase
      test "initializes with required fields" do
        log_entry = GoodJob.new(
          event: Event::Start
        )

        assert_equal Source::Job, log_entry.source
        assert_equal Event::Start, log_entry.event
        assert_equal Level::Info, log_entry.level
        assert_instance_of Time, log_entry.timestamp
      end

      test "accepts job identification fields" do
        log_entry = GoodJob.new(
          event: Event::Enqueue,
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: "default",
          batch_id: "batch_456",
          job_label: "notifications"
        )

        assert_equal "job_123", log_entry.job_id
        assert_equal "UserNotificationJob", log_entry.job_class
        assert_equal "default", log_entry.queue_name
        assert_equal "batch_456", log_entry.batch_id
        assert_equal "notifications", log_entry.job_label
      end

      test "accepts execution context fields" do
        scheduled_time = Time.now + 1.hour
        log_entry = GoodJob.new(
          event: Event::Start,
          arguments: ["user_123", { notify: true }],
          executions: 2,
          exception_executions: 1,
          execution_time: 1.5,
          scheduled_at: scheduled_time
        )

        assert_equal ["user_123", { notify: true }], log_entry.arguments
        assert_equal 2, log_entry.executions
        assert_equal 1, log_entry.exception_executions
        assert_equal 1.5, log_entry.execution_time
        assert_equal scheduled_time, log_entry.scheduled_at
      end

      test "accepts error information fields" do
        backtrace = ["file1.rb:10", "file2.rb:20"]
        log_entry = GoodJob.new(
          event: Event::Error,
          level: Level::Error,
          error_class: "StandardError",
          error_message: "Job failed",
          error_backtrace: backtrace
        )

        assert_equal Level::Error, log_entry.level
        assert_equal "StandardError", log_entry.error_class
        assert_equal "Job failed", log_entry.error_message
        assert_equal backtrace, log_entry.error_backtrace
      end

      test "accepts GoodJob-specific metadata" do
        log_entry = GoodJob.new(
          event: Event::Log,
          process_id: 1234,
          thread_id: "thread_abc",
          priority: 10,
          cron_key: "daily_cleanup",
          database_connection_name: "primary"
        )

        assert_equal 1234, log_entry.process_id
        assert_equal "thread_abc", log_entry.thread_id
        assert_equal 10, log_entry.priority
        assert_equal "daily_cleanup", log_entry.cron_key
        assert_equal "primary", log_entry.database_connection_name
      end

      test "accepts performance metrics" do
        finished_time = Time.now
        log_entry = GoodJob.new(
          event: Event::Finish,
          wait_time: 0.1,
          run_time: 2.5,
          finished_at: finished_time
        )

        assert_equal 0.1, log_entry.wait_time
        assert_equal 2.5, log_entry.run_time
        assert_equal finished_time, log_entry.finished_at
      end

      test "serializes to hash with all fields" do
        scheduled_time = Time.now + 1.hour
        finished_time = Time.now
        backtrace = ["file1.rb:10", "file2.rb:20"]
        
        log_entry = GoodJob.new(
          event: Event::Finish,
          level: Level::Info,
          job_id: "job_123",
          job_class: "UserNotificationJob",
          queue_name: "default",
          batch_id: "batch_456",
          job_label: "notifications",
          arguments: ["user_123"],
          executions: 1,
          exception_executions: 0,
          execution_time: 1.5,
          scheduled_at: scheduled_time,
          error_class: nil,
          error_message: nil,
          error_backtrace: nil,
          process_id: 1234,
          thread_id: "thread_abc",
          priority: 5,
          cron_key: "daily",
          database_connection_name: "primary",
          wait_time: 0.1,
          run_time: 2.5,
          finished_at: finished_time,
          additional_data: { custom_field: "value" }
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
        assert_equal "batch_456", hash[:batch_id]
        assert_equal "notifications", hash[:job_label]

        # Check execution context
        assert_equal ["user_123"], hash[:arguments]
        assert_equal 1, hash[:executions]
        assert_equal 0, hash[:exception_executions]
        assert_equal 1.5, hash[:execution_time]
        assert_equal scheduled_time.iso8601, hash[:scheduled_at]

        # Check GoodJob metadata
        assert_equal 1234, hash[:pid]
        assert_equal "thread_abc", hash[:tid]
        assert_equal 5, hash[:priority]
        assert_equal "daily", hash[:cron_key]
        assert_equal "primary", hash[:database_connection_name]

        # Check performance metrics
        assert_equal 0.1, hash[:wait_time]
        assert_equal 2.5, hash[:run_time]
        assert_equal finished_time.iso8601, hash[:finished_at]

        # Check additional data
        assert_equal "value", hash[:custom_field]
      end

      test "serializes with only present fields" do
        log_entry = GoodJob.new(
          event: Event::Start,
          job_id: "job_123"
        )

        hash = log_entry.serialize

        # Should include present fields
        assert_equal "job", hash[:src]
        assert_equal "start", hash[:evt]
        assert_equal "job_123", hash[:job_id]

        # Should not include nil fields
        refute hash.key?(:job_class)
        refute hash.key?(:queue_name)
        refute hash.key?(:error_message)
        refute hash.key?(:finished_at)
      end

      test "handles all valid event types" do
        # Test each valid event type
        [
          Event::Log,
          Event::Enqueue,
          Event::Start,
          Event::Finish,
          Event::Error,
          Event::Schedule
        ].each do |event|
          log_entry = GoodJob.new(event: event)
          assert_equal event, log_entry.event
        end
      end

      test "additional_data field works correctly" do
        log_entry = GoodJob.new(
          event: Event::Log,
          additional_data: {
            user_id: 123,
            request_id: "req_abc",
            custom_metric: 42.5
          }
        )

        hash = log_entry.serialize
        assert_equal 123, hash[:user_id]
        assert_equal "req_abc", hash[:request_id]
        assert_equal 42.5, hash[:custom_metric]
      end

      test "timestamp is automatically set" do
        before_time = Time.now
        log_entry = GoodJob.new(event: Event::Log)
        after_time = Time.now

        assert log_entry.timestamp >= before_time
        assert log_entry.timestamp <= after_time
      end

      test "includes proper interfaces" do
        assert GoodJob.included_modules.include?(Interfaces::CommonFields)
        assert GoodJob.included_modules.include?(Interfaces::AdditionalDataField)
        assert GoodJob.included_modules.include?(SerializeCommon)
        assert GoodJob.included_modules.include?(MergeAdditionalDataFields)
      end
    end
  end
end