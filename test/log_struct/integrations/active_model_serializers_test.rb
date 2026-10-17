# typed: true
# frozen_string_literal: true

require "test_helper"
require "active_support/notifications"

module LogStruct
  module Integrations
    class ActiveModelSerializersTest < ActiveSupport::TestCase
      setup do
        # Define a marker module to simulate AMS presence
        Object.const_set(:ActiveModelSerializers, Module.new) unless defined?(::ActiveModelSerializers)
        Integrations::ActiveModelSerializers.setup(LogStruct.config)
      end

      teardown do
        # Each setup subscribes again
        ActiveSupport::Notifications.notifier.listeners_for("render.active_model_serializers").each do |listener|
          ActiveSupport::Notifications.unsubscribe(listener)
        end
        if defined?(::ActiveModelSerializers)
          Object.send(:remove_const, :ActiveModelSerializers)
        end
      end

      test "subscribes to AMS notifications and emits structured log" do
        logs = []
        LogStruct.stub(:info, ->(log) { logs << log }) do
          serializer_class = Class.new do
            def self.name
              "UserSerializer"
            end
          end

          adapter_class = Class.new do
            def self.name
              "ActiveModelSerializers::Adapter::Json"
            end
          end
          adapter_instance = adapter_class.new

          resource = OpenStruct.new(id: 1)

          ActiveSupport::Notifications.instrument(
            "render.active_model_serializers",
            serializer: serializer_class,
            adapter: adapter_instance,
            resource: resource
          ) { sleep 0.001 }
        end

        assert_equal 1, logs.size
        log = logs.first

        assert_kind_of LogStruct::Log::ActiveModelSerializers, log
        json = log.as_json

        assert_equal "rails", json["src"]
        assert_equal "generate", json["evt"]
        assert_equal "ams.render", json["msg"]
        assert_equal "UserSerializer", json["serializer"]
        assert_equal "ActiveModelSerializers::Adapter::Json", json["adapter"]
        assert_equal "OpenStruct", json["resource_class"]
        assert_in_delta 0.0, json["duration_ms"], 50.0
      end

      test "a problem with the log line doesn't fail the render in production" do
        handled = []
        LogStruct.stub(:is_production?, true) do
          LogStruct.stub(:info, ->(_log) { raise "formatter broke" }) do
            LogStruct.stub(:handle_exception, ->(error, source:, context:) { handled << [error.message, source, context] }) do
              assert_equal :rendered, ActiveSupport::Notifications.instrument("render.active_model_serializers") { :rendered }
            end
          end
        end

        assert_equal [["formatter broke", LogStruct::Source::Internal, {integration: :active_model_serializers}]], handled
      end
    end
  end
end
