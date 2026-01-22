# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStruct::Integrations::ActiveJobTest < Minitest::Test
  class EventReporterStub
    extend T::Sig

    sig { returns(T::Array[T.untyped]) }
    attr_reader :unsubscribed

    sig { void }
    def initialize
      @unsubscribed = T.let([], T::Array[T.untyped])
    end

    sig { params(subscriber: T.untyped).void }
    def unsubscribe(subscriber)
      @unsubscribed << subscriber
    end
  end

  def setup
    @config = LogStruct.config
    @config.enabled = true
    @config.integrations.enable_activejob = true
  end

  def test_setup_detaches_default_log_subscriber_when_supported
    detach_calls = []
    attach_calls = []

    ::ActiveJob::LogSubscriber.stub(:detach_from, ->(name) { detach_calls << name }) do
      LogStruct::Integrations::ActiveJob::LogSubscriber.stub(:attach_to, ->(name) { attach_calls << name }) do
        LogStruct::Integrations::ActiveJob.setup(@config)
      end
    end

    assert_equal([:active_job], detach_calls)
    assert_equal([:active_job], attach_calls)
  end

  def test_setup_unsubscribes_event_reporter_when_detach_unavailable
    original_log_subscriber = T.let(::ActiveJob::LogSubscriber, T.class_of(Object))
    ::ActiveJob.send(:remove_const, :LogSubscriber)
    ::ActiveJob.const_set(:LogSubscriber, Class.new)

    reporter = T.let(EventReporterStub.new, EventReporterStub)

    original_event_reporter_method = T.let(nil, T.nilable(Method))
    if ::ActiveSupport.respond_to?(:event_reporter)
      original_event_reporter_method = ::ActiveSupport.method(:event_reporter)
    end

    ::ActiveSupport.singleton_class.define_method(:event_reporter) { reporter }

    attach_calls = []
    LogStruct::Integrations::ActiveJob::LogSubscriber.stub(:attach_to, ->(name) { attach_calls << name }) do
      LogStruct::Integrations::ActiveJob.setup(@config)
    end

    assert_equal([::ActiveJob::LogSubscriber], reporter.unsubscribed)
    assert_equal([:active_job], attach_calls)
  ensure
    if original_event_reporter_method
      ::ActiveSupport.singleton_class.define_method(:event_reporter, original_event_reporter_method)
    else
      ::ActiveSupport.singleton_class.send(:remove_method, :event_reporter)
    end

    if ::ActiveJob.const_defined?(:LogSubscriber)
      ::ActiveJob.send(:remove_const, :LogSubscriber)
    end
    ::ActiveJob.const_set(:LogSubscriber, original_log_subscriber)
  end
end
