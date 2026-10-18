# typed: strict
# frozen_string_literal: true

Rails.application.routes.draw do
  # Testing routes
  get "/logging/basic", to: "logging#test_basic"
  get "/logging/error", to: "logging#test_error"
  get "/logging/model", to: "logging#test_model"
  get "/logging/job", to: "logging#test_job"
  get "/logging/context", to: "logging#test_context"
  get "/logging/custom", to: "logging#test_custom"
  get "/logging/request", to: "logging#test_request"
  get "/logging/error_logging", to: "logging#test_error_logging"
  get "/logging/shrine_upload", to: "logging#test_shrine_upload"
  get "/logging/ams", to: "logging#test_ams_serialization"
  post "/logging/params", to: "logging#test_params"

  post "/security/submit", to: "security#submit"
  get "/security/remote_ip", to: "security#remote_ip"

  # Error pages, for config.exceptions_app = routes
  %w[400 404 422 500].each { |status| match "/#{status}", to: "errors#show", via: :all }

  # Healthcheck route
  get "/health", to: proc { [200, {}, ["OK"]] }
end
