# typed: true
# frozen_string_literal: true

require "test_helper"

class LogstructTest < ActionDispatch::IntegrationTest
  # Basic test to ensure the Rails app is working
  test "healthcheck works" do
    get "/health"
    assert_response :success
    assert_equal "OK", response.body
  end
  
  # More detailed test to verify basic logging
  test "basic logging endpoint works" do
    get "/logging/basic"
    assert_response :success
    
    response_json = JSON.parse(response.body)
    assert_equal "ok", response_json["status"]
    assert_equal "Basic logging completed", response_json["message"]
  end
end