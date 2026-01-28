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

        private

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
