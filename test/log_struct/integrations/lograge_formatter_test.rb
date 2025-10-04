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
    end
  end
end
