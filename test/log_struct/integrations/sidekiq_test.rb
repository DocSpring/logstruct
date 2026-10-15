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
    end
  end
end
