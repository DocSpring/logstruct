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

      test "a line logged outside a job has no ctx" do
        Sidekiq::Logger.new("Sidekiq-Server").info("Booted")
        ::SemanticLogger.flush

        line = JSON.parse(T.must(@io.string.lines.last))

        assert_equal "Booted", line["msg"]
        assert_not line.key?("ctx")
      end

      test "Hashes and payloads logged through Sidekiq's logger are filtered, not turned into strings" do
        logger = Sidekiq::Logger.new("Sidekiq-Server")
        logger.info({event: "settings", password: "hunter2"})
        logger.info("Synced", order_id: 7, api_token: "tok-1")
        error = ArgumentError.new("bad")
        logger.warn("Retrying", error)
        ::SemanticLogger.flush

        lines = @io.string.lines.map { |line| JSON.parse(line) }.last(3)

        assert_not_includes @io.string, "hunter2"
        assert_not_includes @io.string, "tok-1"
        assert_equal({"_filtered" => {"_class" => "String"}}, lines[0]["password"])
        assert_equal %w[sidekiq Synced], lines[1].values_at("src", "msg")
        assert_equal 7, lines[1]["order_id"]
        assert_equal %w[error ArgumentError Retrying bad], lines[2].values_at("evt", "error_class", "msg", "error_message")
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

      test "the job's context is filtered and scrubbed like the rest of the line" do
        ::SemanticLogger.named_tagged(sidekiq_context: {jid: "abc123", api_token: "tok-1", note: "ada@example.com"}) do
          LogStruct::SemanticLogger::Logger.new("Rails").info("Rendering PDF")
        end
        ::SemanticLogger.flush

        line = JSON.parse(T.must(@io.string.lines.last))

        assert_equal "abc123", line.dig("ctx", "jid")
        assert_equal({"_filtered" => {"_class" => "String"}}, line.dig("ctx", "api_token"))
        assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, line.dig("ctx", "note"))
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

      test "Sidekiq's logger is replaced before config/initializers run" do
        names = Rails.application.initializers.tsort_each.map(&:name)

        assert_operator names.index("logstruct.configure_logger"), :<, names.index(:load_config_initializers)

        sidekiq_config = ::Sidekiq.default_configuration
        saved = sidekiq_config.logger
        sidekiq_config.logger = ::Logger.new(StringIO.new)
        initializer = Rails.application.initializers.find { |i| i.name == "logstruct.configure_logger" }

        # Only the Sidekiq part: replacing Rails.logger again would reset the test appenders
        LogStruct::SemanticLogger::Setup.stub(:configure_semantic_logger, nil) do
          T.must(initializer).run(Rails.application)
        end

        assert_kind_of Sidekiq::Logger, sidekiq_config.logger
      ensure
        sidekiq_config&.logger = saved
      end

      test "restore_logger puts back the logger Sidekiq had" do
        sidekiq_config = ::Sidekiq.default_configuration
        saved = sidekiq_config.logger
        original = ::Logger.new(StringIO.new)
        sidekiq_config.logger = original

        Sidekiq.configure_logger

        assert_kind_of Sidekiq::Logger, sidekiq_config.logger

        Sidekiq.restore_logger

        assert_same original, sidekiq_config.logger
      ensure
        sidekiq_config&.logger = saved
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
        # The job's ID and class are in ctx, as on the lines logged while the job ran
        assert_equal({"jid" => "abc123", "class" => "HardJob"}, line["ctx"])
        assert_equal ["Job raised exception", "default", 2], [line["error_context"], line["queue_name"], line["retry_count"]]
        refute line.key?("jid")
        refute_includes @io.string, "secret@example.com"
      end

      test "an ActiveJob job's error that ActiveJob didn't log is logged" do
        sidekiq_config = ::Sidekiq::Config.new
        sidekiq_config.logger = Sidekiq::Logger.new("Sidekiq-Server")
        Sidekiq.send(:replace_default_error_handler, sidekiq_config)
        # e.g. the job's class was removed in a deploy, so ActiveJob couldn't deserialize it
        error = NameError.new("uninitialized constant RemovedJob")
        job = {"jid" => "def456", "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "RemovedJob", "queue" => "default"}

        sidekiq_config.error_handlers.each { |handler| handler.call(error, {context: "Job raised exception", job: job}, sidekiq_config) }
        ::SemanticLogger.flush

        line = T.must(sidekiq_lines.first)

        assert_equal ["error", "NameError"], [line["evt"], line["error_class"]]
        assert_equal({"jid" => "def456", "class" => "RemovedJob"}, line["ctx"])
      end

      test "errors the ActiveJob integration logged aren't logged again" do
        sidekiq_config = ::Sidekiq::Config.new
        Sidekiq.send(:replace_default_error_handler, sidekiq_config)
        job = {"jid" => "abc123", "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "HardJob"}
        error = ArgumentError.new("boom")
        LogStruct::LoggedErrors.mark(error)

        sidekiq_config.error_handlers.each { |handler| handler.call(error, {job: job}, sidekiq_config) }
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
