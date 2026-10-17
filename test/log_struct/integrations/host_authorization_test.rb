# typed: true
# frozen_string_literal: true

require "test_helper"
require "rack/mock"

module LogStruct
  module Integrations
    class HostAuthorizationTest < ActiveSupport::TestCase
      setup do
        @saved_host_authorization = Rails.application.config.host_authorization
        @env = Rack::MockRequest.env_for("http://blocked.example.com/health")
      end

      teardown do
        Rails.application.config.host_authorization = @saved_host_authorization
      end

      test "the blocked host is logged and the app's own response app responds" do
        Rails.application.config.host_authorization = {response_app: ->(_env) { [418, {}, ["the app's page"]] }}
        logged = []

        # Set up twice, as when the integrations are set up again: one line per blocked request
        2.times { HostAuthorization.setup(LogStruct.config) }
        response = LogStruct.stub(:warn, ->(log) { logged << log }) do
          Rails.application.config.host_authorization[:response_app].call(@env)
        end

        assert_equal [418, {}, ["the app's page"]], response
        assert_equal ["blocked.example.com"], logged.map(&:blocked_host)
      end

      test "without the app's own response app, LogStruct responds with 403" do
        Rails.application.config.host_authorization = {}
        HostAuthorization.setup(LogStruct.config)

        status, = LogStruct.stub(:warn, ->(_log) {}) do
          Rails.application.config.host_authorization[:response_app].call(@env)
        end

        assert_equal 403, status
      end

      test "a problem with the log line still gets the request its response" do
        Rails.application.config.host_authorization = {}
        HostAuthorization.setup(LogStruct.config)
        handled = []

        status, = LogStruct.stub(:warn, ->(_log) { raise "formatter broke" }) do
          LogStruct.stub(:handle_exception, ->(error, source:, context:) { handled << [error.message, source, context] }) do
            Rails.application.config.host_authorization[:response_app].call(@env)
          end
        end

        assert_equal 403, status
        assert_equal [["formatter broke", LogStruct::Source::Internal, {integration: :host_authorization}]], handled
      end
    end
  end
end
