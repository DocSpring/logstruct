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
            def track(name, properties = {}, _options = {})
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

      test "properties that aren't a Hash and Symbol event names are logged without raising" do
        logs = []

        LogStruct.stub(:info, ->(log) { logs << log }) do
          assert_equal [:ok, :signup, "not a hash"], ::Ahoy::Tracker.new.track(:signup, "not a hash")
        end

        json = logs.fetch(0).as_json

        assert_equal "signup", json["ahoy_event"]
        assert_equal({_class: "String"}, json["properties"])
      end

      test "parameter properties are bounded without converting the full input" do
        LogStruct.config.limits.max_hash_keys = 1
        params = ::ActionController::Parameters.new("visible" => "yes", "ignored" => {"password" => "secret"})

        params.stub(:to_unsafe_h, -> { raise "full conversion" }) do
          assert_equal({visible: "yes", _more_keys: true}, Integrations::Ahoy.properties_for_log(params))
        end
      end

      test "Ahoy gets the arguments as they were given, so its defaults still apply" do
        LogStruct.stub(:info, ->(_log) {}) do
          assert_equal [:ok, "signup", {}], ::Ahoy::Tracker.new.track("signup")
        end
      end

      test "a problem with the log line doesn't fail the tracking call in production" do
        handled = []
        LogStruct.stub(:is_production?, true) do
          LogStruct.stub(:info, ->(_log) { raise "formatter broke" }) do
            LogStruct.stub(:handle_exception, ->(error, source:, context:) { handled << [error.message, source, context] }) do
              assert_equal [:ok, "signup", {}], ::Ahoy::Tracker.new.track("signup")
            end
          end
        end

        assert_equal [["formatter broke", LogStruct::Source::Internal, {integration: :ahoy}]], handled
      end
    end
  end
end
