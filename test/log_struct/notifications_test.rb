# typed: true
# frozen_string_literal: true

require "test_helper"

class LogStructNotificationsTest < Minitest::Test
  def setup
    @events = []
    @subscription = ActiveSupport::Notifications.subscribe("log.logstruct") do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
  end

  def test_error_method_emits_notification
    error_log = LogStruct::Log::Error.new(
      source: LogStruct::Source::Mailer,
      error_class: StandardError,
      message: "test error"
    )

    Rails.logger.error(error_log)

    assert_equal 1, @events.length
    event = @events.first

    assert_equal "log.logstruct", event.name
    assert_equal error_log, event.payload[:log]
    assert_equal :error, event.payload[:level]
  end

  def test_info_method_emits_notification
    plain_log = LogStruct::Log::Plain.new(
      source: LogStruct::Source::App,
      event: LogStruct::Event::Log,
      message: "test info"
    )

    Rails.logger.info(plain_log)

    assert_equal 1, @events.length
    event = @events.first

    assert_equal "log.logstruct", event.name
    assert_equal plain_log, event.payload[:log]
    assert_equal :info, event.payload[:level]
  end

  def test_warn_method_emits_notification
    plain_log = LogStruct::Log::Plain.new(
      source: LogStruct::Source::App,
      event: LogStruct::Event::Log,
      message: "test warning"
    )

    Rails.logger.warn(plain_log)

    assert_equal 1, @events.length
    event = @events.first

    assert_equal :warn, event.payload[:level]
  end

  def test_debug_method_emits_notification
    plain_log = LogStruct::Log::Plain.new(
      source: LogStruct::Source::App,
      event: LogStruct::Event::Log,
      message: "test debug"
    )

    Rails.logger.debug(plain_log)

    assert_equal 1, @events.length
    event = @events.first

    assert_equal :debug, event.payload[:level]
  end

  def test_fatal_method_emits_notification
    plain_log = LogStruct::Log::Plain.new(
      source: LogStruct::Source::App,
      event: LogStruct::Event::Log,
      message: "test fatal"
    )

    Rails.logger.fatal(plain_log)

    assert_equal 1, @events.length
    event = @events.first

    assert_equal :fatal, event.payload[:level]
  end

  def test_subscribers_can_filter_by_log_type
    action_mailer_errors = T.let([], T::Array[LogStruct::Log::ActionMailer::Error])

    subscription = ActiveSupport::Notifications.subscribe("log.logstruct") do |_name, _start, _finish, _id, payload|
      log = payload[:log]
      action_mailer_errors << log if log.is_a?(LogStruct::Log::ActionMailer::Error)
    end

    # Log different types
    Rails.logger.info(LogStruct::Log::Plain.new(source: LogStruct::Source::App, event: LogStruct::Event::Log, message: "plain"))

    Rails.logger.error(LogStruct::Log::ActionMailer::Error.new(
      mailer_class: "TestMailer",
      mailer_action: "test",
      error_class: StandardError,
      message: "bounce!"
    ))

    Rails.logger.error(LogStruct::Log::Error.new(
      source: LogStruct::Source::App,
      error_class: StandardError,
      message: "generic error"
    ))

    assert_equal 1, action_mailer_errors.length
    assert_equal "TestMailer", T.must(action_mailer_errors.first).mailer_class

    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
