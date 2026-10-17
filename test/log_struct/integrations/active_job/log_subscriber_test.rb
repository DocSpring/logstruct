# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/integrations/active_job/log_subscriber"
require "active_support/notifications"
require "time"

module LogStruct
  module Integrations
    module ActiveJob
      class LogSubscriberTest < ActiveSupport::TestCase
        class TestActiveJob < ::ActiveJob::Base
          def perform
          end
        end

        class TestMailer < ::ActionMailer::Base
        end

        setup do
          @original_logger = ::ActiveJob::Base.logger
          @log_output = setup_isolated_logger
          ::ActiveJob::Base.logger = LogStruct::SemanticLogger::Logger.new("TestLogger")
          @subscriber = LogSubscriber.new
        end

        teardown do
          ::ActiveJob::Base.logger = @original_logger
          teardown_isolated_logger
        end

        test "converts monotonic event times to wall clock" do
          clear_log_buffer(@log_output)

          job = TestActiveJob.new
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          finish_time = start_time + 0.2
          event = build_event("perform.active_job", start_time, finish_time, {job: job})

          @subscriber.perform(event)
          ::SemanticLogger.flush

          log = parse_first_log(@log_output)
          ts = ::Time.iso8601(log["ts"])
          finished_at = ::Time.iso8601(log["finished_at"])
          now = ::Time.now

          assert_in_delta now.to_f, ts.to_f, 5.0
          assert_in_delta now.to_f, finished_at.to_f, 5.0
        end

        test "logs Integer provider job IDs as strings" do
          clear_log_buffer(@log_output)

          job = TestActiveJob.new
          job.provider_job_id = 2905
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          event = build_event("perform.active_job", start_time, start_time + 0.1, {job: job})

          @subscriber.perform(event)
          ::SemanticLogger.flush

          assert_equal "2905", parse_first_log(@log_output)["provider_job_id"]
        end

        # GoodJob passes the same exception to on_thread_error, and shouldn't log it again
        test "marks the exceptions it logs" do
          error = RuntimeError.new("boom")
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          event = build_event("perform.active_job", start_time, start_time + 0.1, {job: TestActiveJob.new, exception_object: error})

          refute LogStruct::LoggedErrors.logged?(error)
          @subscriber.perform(event)

          assert LogStruct::LoggedErrors.logged?(error)
        end

        # perform_now lets any Exception through
        test "logs a failed job's exception that isn't a StandardError" do
          clear_log_buffer(@log_output)
          error = NotImplementedError.new("not yet")
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          event = build_event("perform.active_job", start_time, start_time + 0.1, {job: TestActiveJob.new, exception_object: error})

          @subscriber.perform(event)
          ::SemanticLogger.flush

          log = parse_first_log(@log_output)

          assert_equal ["job", "error", "NotImplementedError", TestActiveJob.name], log.values_at("src", "evt", "error_class", "job_class")
          assert_equal "not yet", log["msg"]
        end

        test "logs only the mailer, the mail and the delivery method for a mail delivery job" do
          clear_log_buffer(@log_output)

          # Devise's deliver_later passes the raw token as a plain string
          mailer = TestMailer.name
          job = ::ActionMailer::MailDeliveryJob.new(
            mailer,
            "reset_password_instructions",
            "deliver_now",
            args: ["gid://app/User/1", "raw-reset-password-token", {}]
          )
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          @subscriber.perform_start(build_event("perform_start.active_job", start_time, start_time, {job: job}))
          @subscriber.perform(build_event("perform.active_job", start_time, start_time + 0.1, {job: job}))
          ::SemanticLogger.flush

          logs = @log_output.string.lines.select { |line| line.strip.start_with?("{") }.map { |line| JSON.parse(line) }

          assert_equal 2, logs.size
          logs.each do |log|
            assert_equal [mailer, "reset_password_instructions", "deliver_now"], log["arguments"]
          end
          refute_includes @log_output.string, "raw-reset-password-token"
        end

        test "logs other jobs' arguments" do
          clear_log_buffer(@log_output)

          job = TestActiveJob.new("report", 42)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          @subscriber.perform(build_event("perform.active_job", start_time, start_time + 0.1, {job: job}))
          ::SemanticLogger.flush

          assert_equal ["report", 42], parse_first_log(@log_output)["arguments"]
        end

        test "the finish line's ts is when the job finished, and its times have milliseconds" do
          clear_log_buffer(@log_output)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

          @subscriber.perform(build_event("perform.active_job", start_time - 2.5, start_time, {job: TestActiveJob.new}))
          ::SemanticLogger.flush

          log = parse_first_log(@log_output)

          assert_equal log["finished_at"], log["ts"]
          assert_match(/\.\d{3}/, log["finished_at"])
        end

        test "a job the queue couldn't take writes an error line, not an enqueue line" do
          clear_log_buffer(@log_output)
          job = TestActiveJob.new
          # perform_later rescues EnqueueError and keeps it on the job
          job.enqueue_error = ::ActiveJob::EnqueueError.new("Redis is down")
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

          @subscriber.enqueue(build_event("enqueue.active_job", start_time, start_time, {job: job}))
          ::SemanticLogger.flush

          log = parse_first_log(@log_output)

          assert_equal ["error", "error", "ActiveJob::EnqueueError", "Redis is down", job.job_id], log.values_at("evt", "lvl", "error_class", "msg", "job_id")
        end

        test "a scheduled job that raised while enqueuing writes an error line" do
          clear_log_buffer(@log_output)
          job = TestActiveJob.new
          job.scheduled_at = ::Time.now + 60
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          payload = {job: job, exception_object: ArgumentError.new("bad queue")}

          @subscriber.enqueue_at(build_event("enqueue_at.active_job", start_time, start_time, payload))
          ::SemanticLogger.flush

          assert_equal ["error", "ArgumentError"], parse_first_log(@log_output).values_at("evt", "error_class")
        end

        # The inline adapter runs the job inside perform_later, and its error raises out of the enqueue
        test "an enqueue error the perform line already logged isn't logged again" do
          clear_log_buffer(@log_output)
          error = RuntimeError.new("boom")
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

          @subscriber.perform(build_event("perform.active_job", start_time, start_time + 0.1, {job: TestActiveJob.new, exception_object: error}))
          @subscriber.enqueue(build_event("enqueue.active_job", start_time, start_time + 0.1, {job: TestActiveJob.new, exception_object: error}))
          ::SemanticLogger.flush

          assert_equal ["error"], json_lines(@log_output).map { |log| log["evt"] }
        end

        test "a job a before_enqueue callback stopped writes no line" do
          clear_log_buffer(@log_output)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

          @subscriber.enqueue(build_event("enqueue.active_job", start_time, start_time, {job: TestActiveJob.new, aborted: true}))
          ::SemanticLogger.flush

          assert_empty json_lines(@log_output)
        end

        test "perform_all_later writes a line for each job it enqueued or scheduled" do
          clear_log_buffer(@log_output)
          now_job = TestActiveJob.new
          now_job.successfully_enqueued = true
          later_job = TestActiveJob.new
          later_job.scheduled_at = ::Time.now + 60
          later_job.successfully_enqueued = true
          failed_job = TestActiveJob.new
          failed_job.successfully_enqueued = false
          failed_job.enqueue_error = ::ActiveJob::EnqueueError.new("Redis is down")
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          payload = {adapter: nil, jobs: [now_job, later_job, failed_job], enqueued_count: 2}

          @subscriber.enqueue_all(build_event("enqueue_all.active_job", start_time, start_time, payload))
          ::SemanticLogger.flush

          assert_equal(
            [["enqueue", now_job.job_id], ["schedule", later_job.job_id], ["error", failed_job.job_id]],
            json_lines(@log_output).map { |log| log.values_at("evt", "job_id") }
          )
        end

        test "retry_on writes a retry line with the exception and the wait" do
          clear_log_buffer(@log_output)
          job = TestActiveJob.new
          job.executions = 1
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          payload = {job: job, error: Timeout::Error.new("API timed out"), wait: 3.seconds}

          @subscriber.enqueue_retry(build_event("enqueue_retry.active_job", start_time, start_time, payload))
          ::SemanticLogger.flush

          log = parse_first_log(@log_output)

          assert_equal ["retry", "info", "Timeout::Error", "API timed out", 3000.0, 1], log.values_at("evt", "lvl", "error_class", "msg", "wait_ms", "executions")
        end

        test "retry_on running out of attempts writes a retry_stopped line" do
          clear_log_buffer(@log_output)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          payload = {job: TestActiveJob.new, error: Timeout::Error.new("API timed out")}

          @subscriber.retry_stopped(build_event("retry_stopped.active_job", start_time, start_time, payload))
          ::SemanticLogger.flush

          assert_equal ["retry_stopped", "error", "Timeout::Error"], parse_first_log(@log_output).values_at("evt", "lvl", "error_class")
        end

        test "discard_on writes a discard line" do
          clear_log_buffer(@log_output)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
          payload = {job: TestActiveJob.new, error: ArgumentError.new("Unknown invoice")}

          @subscriber.discard(build_event("discard.active_job", start_time, start_time, payload))
          ::SemanticLogger.flush

          assert_equal ["discard", "error", "ArgumentError", "Unknown invoice"],
            parse_first_log(@log_output).values_at("evt", "lvl", "error_class", "msg")
        end

        test "a job a before_perform callback stopped writes no finish line" do
          clear_log_buffer(@log_output)
          start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

          @subscriber.perform(build_event("perform.active_job", start_time, start_time + 0.1, {job: TestActiveJob.new, aborted: true}))
          ::SemanticLogger.flush

          assert_empty json_lines(@log_output)
        end

        private

        def json_lines(io)
          io.string.lines.select { |line| line.strip.start_with?("{") }.map { |line| JSON.parse(line) }
        end

        def build_event(name, start_time, finish_time, payload)
          ::ActiveSupport::Notifications::Event.new(name, start_time, finish_time, "test", payload)
        end

        def parse_first_log(io)
          io.rewind
          line = io.string.lines.find { |log_line| log_line.strip.start_with?("{") }

          assert line, "Expected JSON log output, got: #{io.string}"
          JSON.parse(line)
        end
      end
    end
  end
end
