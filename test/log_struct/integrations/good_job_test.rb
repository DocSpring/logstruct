# typed: true
# frozen_string_literal: true

require "test_helper"
require "log_struct/integrations/good_job/logger"

module LogStruct
  module Integrations
    class GoodJobTest < ActiveSupport::TestCase
      # Stands in for GoodJob::CLI
      class FakeGoodJobCLI
        class << self
          attr_accessor :log_to_stdout
        end
      end

      setup do
        @original_config = LogStruct.config
        LogStruct.configuration = LogStruct::Configuration.new
        LogStruct.config.enabled = true
        LogStruct.config.integrations.enable_goodjob = true
      end

      teardown do
        LogStruct.configuration = @original_config
      end

      test "responds to setup method" do
        assert_respond_to GoodJob, :setup
      end

      test "implements IntegrationInterface" do
        assert_includes GoodJob.singleton_class.included_modules, IntegrationInterface
      end

      test "returns early when GoodJob is not defined" do
        # Mock GoodJob as not being defined
        skip_if_goodjob_defined do
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "returns early when LogStruct is disabled" do
        skip_if_goodjob_defined do
          LogStruct.config.enabled = false
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "returns early when GoodJob integration is disabled" do
        skip_if_goodjob_defined do
          LogStruct.config.integrations.enable_goodjob = false
          result = GoodJob.setup(LogStruct.config)

          assert_nil result
        end
      end

      test "configure_logger method exists and is private" do
        assert_includes GoodJob.private_methods, :configure_logger
      end

      test "replaces GoodJob's logger, and logs thread errors as well as passing them to the app's handler" do
        with_fake_goodjob do |fake|
          reported = []
          fake.on_thread_error = ->(exception) { reported << exception.message }

          GoodJob.send(:configure_logger)
          GoodJob.send(:configure_logger)

          assert_instance_of GoodJob::Logger, fake.logger
          assert_same false, FakeGoodJobCLI.log_to_stdout, "GoodJob's executable shouldn't add a plain text STDOUT logger"
          logged = []
          fake.logger.stub(:error, ->(entry) { logged << entry.error_message }) do
            fake._on_thread_error(RuntimeError.new("boom"))
          end

          assert_equal ["boom"], reported
          assert_equal ["boom"], logged
        end
      end

      test "a thread error is one structured error line from GoodJob's logger" do
        io = setup_isolated_logger
        with_fake_goodjob do |fake|
          GoodJob.send(:configure_logger)
          clear_log_buffer(io)

          error = RuntimeError.new("boom")
          error.set_backtrace(["app/jobs/example_job.rb:3:in 'perform'"])
          fake._on_thread_error(error)
          ::SemanticLogger.flush

          lines = io.string.lines.map { |line| JSON.parse(line) }

          assert_equal 1, lines.length
          assert_equal %w[job error error RuntimeError boom],
            lines[0].values_at("src", "evt", "lvl", "error_class", "error_message")
        end
      ensure
        teardown_isolated_logger
      end

      # In a Rails app, GoodJob's engine sets config.good_job.on_thread_error in an after_initialize
      # block that runs after LogStruct's setup
      test "logs thread errors when the app sets its handler after LogStruct's setup" do
        with_fake_goodjob do |fake|
          2.times { GoodJob.setup(LogStruct.config) }

          reported = []
          fake.on_thread_error = ->(exception) { reported << exception.message }

          logged = []
          fake.logger.stub(:error, ->(entry) { logged << entry.error_message }) do
            fake._on_thread_error(RuntimeError.new("boom"))
          end

          assert_equal ["boom"], reported
          assert_equal ["boom"], logged
        end
      end

      test "GoodJob's own error lines have no backtrace, and thread errors are left to the thread error handler" do
        with_fake_goodjob do |fake|
          # Like GoodJob::LogSubscriber: it logs errors as text with the whole backtrace in the message
          log_subscriber = Class.new do
            attr_reader :lines

            def initialize
              @lines = []
            end

            def finished_timer_task(event) = @lines << [:timer, event]

            def finished_job_task(event) = @lines << [:job, event]

            def notifier_notify_error(event) = error { "Notifier errored: #{event.payload[:error].backtrace}" }

            def systemd_watchdog_error(event) = error { "Error pinging systemd: #{event.payload[:error].backtrace}" }

            def scheduler_create_pool(event) = @lines << [:pool, event]

            def error(progname = nil, tags: [], &block) = @lines << [:error, block ? yield : progname]
          end
          fake.const_set(:LogSubscriber, log_subscriber)

          2.times { GoodJob.setup(LogStruct.config) }

          error = IOError.new("connection lost")
          error.set_backtrace(["lib/good_job/notifier.rb:1:in 'listen'"])
          event = Struct.new(:payload).new({error: error})
          subscriber = log_subscriber.new
          subscriber.finished_timer_task(event)
          subscriber.finished_job_task(event)
          subscriber.notifier_notify_error(event)
          subscriber.systemd_watchdog_error(event)
          subscriber.scheduler_create_pool(:event)

          assert_equal [
            [:error, "Notifier errored: IOError: connection lost"],
            [:error, "Error pinging systemd: IOError: connection lost"],
            [:pool, :event]
          ],
            subscriber.lines
          assert_equal 1, log_subscriber.ancestors.count(GoodJob::CompactErrorLines)
        end
      end

      test "integration is included in automatic setup" do
        # Check that GoodJob is required in integrations.rb
        integrations_file = File.read(
          File.join(__dir__, "../../../lib/log_struct/integrations.rb")
        )

        assert_includes integrations_file, 'require_relative "integrations/good_job"'

        # Check that setup is called conditionally
        assert_includes integrations_file,
          "Integrations::GoodJob.setup(config) if config.integrations.enable_goodjob"
      end

      test "configuration option exists" do
        assert_respond_to LogStruct.config.integrations, :enable_goodjob
        assert LogStruct.config.integrations.enable_goodjob
      end

      private

      # Stands in for the GoodJob gem, which isn't installed for the tests
      def with_fake_goodjob
        fake = Module.new do
          class << self
            attr_accessor :logger, :on_thread_error

            # Like GoodJob: every thread error goes through here
            def _on_thread_error(exception)
              on_thread_error.call(exception) if on_thread_error.respond_to?(:call)
            end
          end
        end
        FakeGoodJobCLI.log_to_stdout = nil
        fake.const_set(:CLI, FakeGoodJobCLI)
        Object.const_set(:GoodJob, fake)
        yield fake
      ensure
        Object.send(:remove_const, :GoodJob)
      end

      def skip_if_goodjob_defined
        if defined?(::GoodJob)
          skip "GoodJob is defined in test environment - cannot test undefined behavior"
        else
          yield
        end
      end
    end
  end
end
