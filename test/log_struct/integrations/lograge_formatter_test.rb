# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    class LogrageFormatterTest < ActiveSupport::TestCase
      def setup
        @formatter = Rails.application.config.lograge.formatter

        raise "lograge.formatter should be configured by LogStruct" unless @formatter
      end

      def test_normalizes_symbol_and_mixed_types
        data = {
          method: :GET,
          path: "/users",
          format: :json,
          controller: :Templates,
          action: :index,
          status: 200,
          duration: 12.34,
          view: 1.23,
          db: 0.45,
          params: {"foo" => "bar", "nested" => {"inner" => "x"}}
        }

        log = @formatter.call(data)

        assert_kind_of LogStruct::Log::Request, log
        assert_equal "GET", log.http_method
        assert_equal "/users", log.path
        assert_equal :json, log.format
        assert_equal "Templates", log.controller
        assert_equal "index", log.action
        assert_equal 200, log.status
        assert_in_delta 12.34, log.duration_ms
        assert_in_delta 1.23, log.view
        assert_in_delta 0.45, log.database

        # params should be symbolized deeply
        refute_nil log.params
        assert_equal "bar", log.params[:foo]
        assert_equal "x", log.params[:nested][:inner]

        # ensure serialize works without type errors
        json_hash = log.serialize

        assert_equal "GET", json_hash[:method]
        assert_equal :json, json_hash[:format]
        assert_equal :foo, json_hash[:params].keys.first
      end

      def test_handles_nil_fields_gracefully
        data = {
          method: nil,
          path: nil,
          format: nil,
          controller: nil,
          action: nil,
          status: nil,
          duration: nil,
          view: nil,
          db: nil,
          params: nil
        }

        log = T.let(nil, T.nilable(LogStruct::Log::Request))
        assert_silent do
          log = @formatter.call(data)
          T.must(log).serialize # should not raise
        end

        assert_kind_of LogStruct::Log::Request, log
        assert_nil T.must(log).http_method
        assert_nil T.must(log).format
        assert_nil T.must(log).params
      end

      def test_includes_custom_options_and_request_metadata
        data = {
          "method" => "GET",
          "path" => "/users",
          "status" => "200",
          "duration" => "12.34",
          "request_id" => "req-123",
          "source_ip" => "10.0.0.1",
          "user_agent" => "TestAgent/1.0",
          "host" => "example.test",
          "content_type" => "application/json",
          "accept" => "application/json",
          "user_id" => "abc-123",
          "extra_nil" => nil
        }

        log = @formatter.call(data)

        assert_equal "10.0.0.1", log.source_ip
        assert_equal "TestAgent/1.0", log.user_agent
        assert_equal "example.test", log.host
        assert_equal "application/json", log.content_type
        assert_equal "application/json", log.accept

        additional_data = T.must(log.additional_data)

        assert_equal "abc-123", additional_data[:user_id]
        # request_id is now handled by SemanticLogger named_tags, not stored on struct or in additional_data
        refute additional_data.key?(:request_id)
        refute additional_data.key?(:extra_nil)

        json_hash = log.serialize

        assert_equal "abc-123", json_hash[:user_id]
      end

      def test_default_options_include_referer_header
        event = ActiveSupport::Notifications::Event.new(
          "process_action.action_controller",
          Time.now.to_f,
          Time.now.to_f,
          "event-id",
          {
            request_id: "req-456",
            host: "example.test",
            source_ip: "10.0.0.2",
            headers: {
              "HTTP_USER_AGENT" => "TestAgent/2.0",
              "HTTP_REFERER" => "https://example.test/landing",
              "CONTENT_TYPE" => "application/json",
              "HTTP_ACCEPT" => "application/json"
            }
          }
        )

        options = LogStruct::Integrations::Lograge.lograge_default_options(event)

        assert_equal "https://example.test/landing", options[:referer]
        assert_equal "TestAgent/2.0", options[:user_agent]
        assert_equal "application/json", options[:content_type]
        assert_equal "application/json", options[:accept]
      end

      def test_extracts_request_id_from_action_dispatch_header
        event = ActiveSupport::Notifications::Event.new(
          "process_action.action_controller",
          Time.now.to_f,
          Time.now.to_f,
          "event-id",
          {
            host: "example.test",
            headers: {
              "action_dispatch.request_id" => "abc-123-request-id",
              "HTTP_USER_AGENT" => "TestAgent/1.0"
            }
          }
        )

        options = LogStruct::Integrations::Lograge.lograge_default_options(event)

        assert_equal "abc-123-request-id", options[:request_id]
      end

      def test_prefers_payload_request_id_over_header
        # If request_id is in both payload and headers, prefer payload
        event = ActiveSupport::Notifications::Event.new(
          "process_action.action_controller",
          Time.now.to_f,
          Time.now.to_f,
          "event-id",
          {
            request_id: "payload-request-id",
            headers: {
              "action_dispatch.request_id" => "header-request-id"
            }
          }
        )

        options = LogStruct::Integrations::Lograge.lograge_default_options(event)

        assert_equal "payload-request-id", options[:request_id]
      end
    end
  end
end
