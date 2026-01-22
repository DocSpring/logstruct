# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStruct::Integrations::RackErrorHandlerTest < Minitest::Test
  def setup
    @middleware = LogStruct::Integrations::RackErrorHandler::Middleware.new(
      ->(_env) { [200, {}, ["ok"]] }
    )
  end

  def test_csrf_error_handles_invalid_authenticity_token
    defined_auth_token = false
    unless ::ActionController.const_defined?(:InvalidAuthenticityToken)
      ::ActionController.const_set(:InvalidAuthenticityToken, Class.new(StandardError))
      defined_auth_token = true
    end

    error = ::ActionController::InvalidAuthenticityToken.new("csrf")

    assert(@middleware.send(:csrf_error?, error))
  ensure
    if defined_auth_token
      ::ActionController.send(:remove_const, :InvalidAuthenticityToken)
    end
  end

  def test_csrf_error_handles_invalid_cross_origin_request
    defined_cross_origin = false
    unless ::ActionController.const_defined?(:InvalidCrossOriginRequest)
      ::ActionController.const_set(:InvalidCrossOriginRequest, Class.new(StandardError))
      defined_cross_origin = true
    end

    error = ::ActionController::InvalidCrossOriginRequest.new("csrf")

    assert(@middleware.send(:csrf_error?, error))
  ensure
    if defined_cross_origin
      ::ActionController.send(:remove_const, :InvalidCrossOriginRequest)
    end
  end
end
