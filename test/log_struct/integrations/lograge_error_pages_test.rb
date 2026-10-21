# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module Integrations
    # Error pages from the app's own controller (config.exceptions_app = routes). The Rails test app's ErrorPagesTest
    # sends real requests through them.
    class LogrageErrorPagesTest < ActiveSupport::TestCase
      setup do
        @request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/orders/42", method: "POST"))
      end

      test "an error the action's line logged makes the error page's line a repeat" do
        Lograge.lograge_default_options(event(exception: ["RuntimeError", "Test error"]))
        render_error_page

        assert Lograge.repeated_error_page?(event)
      end

      test "an error after an action's line that logged none, such as a middleware's, keeps the error page's line" do
        Lograge.lograge_default_options(event)
        render_error_page

        refute Lograge.repeated_error_page?(event)
      end

      test "an error page's line has the request's method, and its path under the app's mount point" do
        @request.script_name = "/shop"
        render_error_page

        assert_equal ["POST", "/shop/orders/42"], Lograge.lograge_default_options(event).values_at(:method, :path)
      end

      test "only error pages are repeats" do
        refute Lograge.repeated_error_page?(event(exception: ["RuntimeError", "Test error"]))
        refute Lograge.repeated_error_page?(ActiveSupport::Notifications::Event.new("perform_action.action_cable", nil, nil, "id", {}))
      end

      test "Lograge ignores repeated error pages, with one ignore test" do
        assert_equal 1, ::Lograge.ignore_tests.count(Lograge::IGNORE_REPEATED_ERROR_PAGE)
      end

      private

      # What ActionDispatch::ShowExceptions does before it calls the exceptions app
      def render_error_page
        @request.set_header("action_dispatch.original_path", @request.path_info)
        @request.set_header("action_dispatch.original_request_method", @request.raw_request_method)
        @request.path_info = "/500"
        @request.request_method = "GET"
      end

      def event(**payload)
        ActiveSupport::Notifications::Event.new("process_action.action_controller", nil, nil, "id", {request: @request, **payload})
      end
    end
  end
end
