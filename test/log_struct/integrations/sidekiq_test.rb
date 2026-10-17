# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    class SidekiqTest < ActiveSupport::TestCase
      setup do
        @io = setup_isolated_logger
      end

      teardown do
        teardown_isolated_logger
      end

      test "logs a copy of the Sidekiq context" do
        logged = T.let([], T::Array[T.untyped])
        subscriber = ActiveSupport::Notifications.subscribe("log.logstruct") do |*_args, payload|
          logged << payload[:log]
        end

        ::Sidekiq::Context.with(jid: "abc123", class: "HardJob") do
          Sidekiq::Logger.new("Sidekiq-Server").info("start")
          ::Sidekiq::Context.add(:elapsed, "0.001")
        end

        assert_equal({jid: "abc123", class: "HardJob"}, logged.last.context)
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      test "lines logged while a job runs include the job's ID and class" do
        job_hash = {"jid" => "abc123", "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "HardJob"}

        Sidekiq::JobContextMiddleware.new.call(nil, job_hash, "default") do
          LogStruct::SemanticLogger::Logger.new("Rails").info("Rendering PDF")
        end
        LogStruct::SemanticLogger::Logger.new("Rails").info("After the job")
        ::SemanticLogger.flush

        lines = @io.string.lines.map { |line| JSON.parse(line) }
        inside = lines.find { |line| line["msg"] == "Rendering PDF" }
        after = lines.find { |line| line["msg"] == "After the job" }

        assert_equal({"jid" => "abc123", "class" => "HardJob"}, T.must(inside)["ctx"])
        assert_nil T.must(after)["ctx"]
      end

      test "a logged Hash's own ctx keeps its keys and gains the job's" do
        job_hash = {"jid" => "abc123", "class" => "HardJob"}

        Sidekiq::JobContextMiddleware.new.call(nil, job_hash, "default") do
          LogStruct::SemanticLogger::Logger.new("Rails").info({msg: "Rendering PDF", ctx: {template_id: "tpl_1"}})
        end
        ::SemanticLogger.flush

        line = JSON.parse(T.must(@io.string.lines.last))

        assert_equal({"jid" => "abc123", "class" => "HardJob", "template_id" => "tpl_1"}, line["ctx"])
      end

      test "a failed job is logged once, as a structured line without its arguments" do
        sidekiq_config = ::Sidekiq::Config.new
        sidekiq_config.logger = Sidekiq::Logger.new("Sidekiq-Server")
        Sidekiq.send(:replace_default_error_handler, sidekiq_config)
        error = ArgumentError.new("Template not found")
        error.set_backtrace(["app/jobs/hard_job.rb:12:in 'perform'"])
        job = {"jid" => "abc123",
               "class" => "HardJob",
               "queue" => "default",
               "retry_count" => 2,
               "args" => ["secret@example.com"]}

        sidekiq_config.error_handlers.each { |handler| handler.call(error, {context: "Job raised exception", job: job}, sidekiq_config) }
        ::SemanticLogger.flush

        lines = sidekiq_lines

        assert_equal 1, lines.size
        line = T.must(lines.first)

        assert_equal ["error", "warn"], [line["evt"], line["lvl"]]
        assert_equal ["ArgumentError", "Template not found"], [line["error_class"], line["msg"]]
        assert_equal ["abc123", "HardJob", "default", 2], [line["jid"], line["job_class"], line["queue"], line["retry_count"]]
        refute_includes @io.string, "secret@example.com"
      end

      test "ActiveJob jobs' errors are left to the ActiveJob integration" do
        sidekiq_config = ::Sidekiq::Config.new
        Sidekiq.send(:replace_default_error_handler, sidekiq_config)
        job = {"jid" => "abc123", "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "HardJob"}

        sidekiq_config.error_handlers.each { |handler| handler.call(ArgumentError.new("boom"), {job: job}, sidekiq_config) }
        ::SemanticLogger.flush

        assert_empty sidekiq_lines
      end

      test "an app's own error handlers stay" do
        sidekiq_config = ::Sidekiq::Config.new
        app_handler = ->(_error, _context, _config) {}
        sidekiq_config.error_handlers << app_handler

        Sidekiq.send(:replace_default_error_handler, sidekiq_config)

        refute_includes sidekiq_config.error_handlers, ::Sidekiq::Config::ERROR_HANDLER
        assert_includes sidekiq_config.error_handlers, app_handler
        assert_equal 2, sidekiq_config.error_handlers.size
      end

      private

      def sidekiq_lines
        @io.string.lines.map { |line| JSON.parse(line) }.select { |line| line["src"] == "sidekiq" }
      end
    end
  end
end
