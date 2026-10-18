# typed: true
# frozen_string_literal: true

class SecurityController < ApplicationController
  # The test app is API-only, with no session for protect_from_forgery to check, so this raises the
  # error protect_from_forgery raises for a request without a valid token
  def submit
    raise ActionController::InvalidAuthenticityToken, "Can't verify CSRF token authenticity."
  end

  # Reading remote_ip runs Rails' IP spoofing check
  def remote_ip
    render json: {ip: request.remote_ip}
  end
end
