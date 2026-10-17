# typed: true
# frozen_string_literal: true

require "test_helper"

class SorbetIntegrationTest < Minitest::Test
  HANDLERS = %i[inline_type_error_handler call_validation_error_handler sig_builder_error_handler sig_validation_error_handler].freeze

  class Typed
    extend T::Sig

    sig { params(count: Integer).void }
    def count(count) = nil
  end

  def setup
    @saved_handlers = HANDLERS.to_h { |name| [name, T::Configuration.instance_variable_get(:"@#{name}")] }
    LogStruct::Integrations::Sorbet.setup(LogStruct.config)
  end

  def teardown
    @saved_handlers.each { |name, handler| T::Configuration.send(:"#{name}=", handler) }
  end

  def test_type_errors_are_handled_as_type_checking_errors
    handled = handled_errors do
      T.let(T.unsafe("one"), Integer) # a wrong type on purpose
      Typed.new.count(T.unsafe("two")) # a wrong argument on purpose
      T::Configuration.sig_builder_error_handler(StandardError.new("bad sig"), caller_locations(0, 1)&.first)
      T::Configuration.sig_validation_error_handler(StandardError.new("bad override"), {})
    end

    assert_equal [TypeError, TypeError, StandardError, StandardError], handled.map { |error, _source| error.class }
    assert_equal [LogStruct::Source::TypeChecking], handled.map(&:last).uniq
  end

  def test_type_errors_have_a_backtrace_from_the_code_that_failed
    handled = handled_errors do
      T.let(T.unsafe("one"), Integer) # a wrong type on purpose
      Typed.new.count(T.unsafe("two")) # a wrong argument on purpose
    end

    handled.each do |error, _source|
      assert_match(/\A#{Regexp.escape(__FILE__)}:\d+/, error.backtrace&.first)
    end
  end

  def test_nothing_is_installed_when_the_integration_is_off
    HANDLERS.each { |name| T::Configuration.send(:"#{name}=", nil) }
    config = LogStruct::Configuration.new
    config.integrations.enable_sorbet_error_handlers = false

    assert_nil LogStruct::Integrations::Sorbet.setup(config)
    HANDLERS.each { |name| assert_nil T::Configuration.instance_variable_get(:"@#{name}"), name }
  end

  private

  def handled_errors(&block)
    handled = []
    LogStruct.stub(:handle_exception, ->(error, source:, context: nil, log: true) { handled << [error, source] }, &block)
    handled
  end
end
