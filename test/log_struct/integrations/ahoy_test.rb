# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    class AhoyTest < ActiveSupport::TestCase
      setup do
        # Define a minimal Ahoy::Tracker if not present
        unless Object.const_defined?(:Ahoy)
          Object.const_set(:Ahoy, Module.new)
        end
        unless defined?(::Ahoy::Tracker)
          tracker_class = Class.new do
            def track(name, properties = nil, _options = nil)
              # Return a simple value to verify passthrough
              [:ok, name, properties]
            end
          end
          ::Ahoy.const_set(:Tracker, tracker_class)
        end

        # Activate integration
        Integrations::Ahoy.setup(LogStruct.config)
      end

      teardown do
        # Cleanup constants we created
        if defined?(::Ahoy::Tracker)
          ::Ahoy.send(:remove_const, :Tracker)
        end
        if defined?(::Ahoy)
          Object.send(:remove_const, :Ahoy)
        end
      end

      test "prepends tracker to log events while preserving original behavior" do
        logs = []
        LogStruct.stub(:info, ->(log) { logs << log }) do
          tracker_class = ::Ahoy::Tracker
          tracker = tracker_class.new
          result = tracker.track("signup", {email: "test@example.com", plan: "pro"})

          assert_equal [:ok, "signup", {email: "test@example.com", plan: "pro"}], result
        end

        assert_equal 1, logs.size
        log = logs.first

        assert_kind_of LogStruct::Log::Ahoy, log
        json = log.as_json

        assert_equal "app", json["src"]
        assert_equal "log", json["evt"]
        assert_equal "ahoy.track", json["msg"]
        # Ensure some data made it through
        assert_equal "signup", json["ahoy_event"]
        assert_kind_of Hash, json["properties"]
      end
    end
  end
end
