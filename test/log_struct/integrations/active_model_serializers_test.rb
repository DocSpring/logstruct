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
        if defined?(::ActiveModelSerializers)
          Object.send(:remove_const, :ActiveModelSerializers)
        end
      end

      test "subscribes to AMS notifications and emits structured log" do
        logs = []
        LogStruct.stub(:info, ->(log) { logs << log }) do
          serializer = Class.new do
            def self.to_s
              "UserSerializer"
            end
          end
          resource = OpenStruct.new(id: 1)

          ActiveSupport::Notifications.instrument(
            "render.active_model_serializers",
            serializer: serializer,
            adapter: :json,
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
        assert_equal "json", json["adapter"]
        assert_equal "OpenStruct", json["resource_class"]
        assert_in_delta 0.0, json["duration_ms"], 50.0
      end
    end
  end
end
