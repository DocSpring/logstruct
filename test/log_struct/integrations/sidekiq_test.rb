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
    end
  end
end
