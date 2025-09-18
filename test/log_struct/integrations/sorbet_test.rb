# typed: true
# frozen_string_literal: true

require "test_helper"

class SorbetIntegrationTest < Minitest::Test
  def setup
    LogStruct::Integrations::Sorbet.instance_variable_set(:@installed, false)
  end

  def test_patch_clears_existing_sig_error_handler
    LogStruct::Integrations::Sorbet.stub(:clear_sig_error_handler!, -> { @cleared = true }) do
      LogStruct::Integrations::Sorbet.stub(:install_error_handler!, -> { @installed = true }) do
        LogStruct::Integrations::Sorbet.setup(LogStruct.config)
      end
    end

    assert @cleared
    assert @installed
  end

  def test_clear_sig_error_handler_when_defined
    handler = proc {}
    T::Configuration.sig_builder_error_handler = handler

    LogStruct::Integrations::Sorbet.send(:clear_sig_error_handler!)

    assert_nil current_sig_builder_error_handler
  ensure
    T::Configuration.sig_builder_error_handler = nil
  end

  def test_clear_sig_error_handler_when_nil
    T::Configuration.sig_builder_error_handler = nil

    assert_nil LogStruct::Integrations::Sorbet.send(:clear_sig_error_handler!)
  end

  def test_install_error_handler_sets_handler_once
    called = []
    LogStruct::Integrations::Sorbet.send(:clear_sig_error_handler!)

    T::Configuration.sig_builder_error_handler = nil

    LogStruct.stub(
      :handle_exception,
      ->(error, source:, context: nil) { called << [error.class, source] }
    ) do
      LogStruct::Integrations::Sorbet.send(:install_error_handler!)

      handler = current_sig_builder_error_handler
      raise "handler not installed" unless handler

      handler.call(StandardError.new("boom"), :example)
    end

    assert_equal [[StandardError, :example]], called
  ensure
    T::Configuration.sig_builder_error_handler = nil
    LogStruct::Integrations::Sorbet.instance_variable_set(:@installed, false)
  end

  private

  def current_sig_builder_error_handler
    T::Configuration.instance_variable_get(:@sig_builder_error_handler)
  end
end
