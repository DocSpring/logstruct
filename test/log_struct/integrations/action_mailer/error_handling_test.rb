# typed: true
# frozen_string_literal: true

require "test_helper"
require "action_mailer"

class ActionMailerErrorHandlingTest < ActiveSupport::TestCase
  class DeliveryFailed < StandardError; end

  # Fails like an email provider rejecting the email
  class FailingDelivery
    def initialize(_settings)
    end

    def deliver!(_mail)
      raise DeliveryFailed, "Invalid 'From' address"
    end
  end

  # LogStruct prepends ErrorHandling to ActionMailer::Base, and apps' mailers inherit it
  class BaseMailer < ActionMailer::Base
    prepend LogStruct::Integrations::ActionMailer::ErrorHandling

    add_delivery_method :logstruct_failing, FailingDelivery
    self.delivery_method = :logstruct_failing
  end

  class FailingMailer < BaseMailer
    def notice
      mail(to: "user@example.com", from: "app@example.com", subject: "Notice", body: "Hello")
    end
  end

  class IgnoringMailer < FailingMailer
    rescue_from DeliveryFailed, with: :log_and_ignore_error
  end

  class ReportingMailer < FailingMailer
    rescue_from DeliveryFailed, with: :log_and_report_error
  end

  setup do
    @orig_logger = ::Rails.logger
    @buf = StringIO.new
    logger = ::Logger.new(@buf)
    logger.formatter = LogStruct::Formatter.new
    ::Rails.logger = logger
    @reported = []
    @orig_standard_errors = LogStruct.config.error_handling_modes.standard_errors
  end

  teardown do
    ::Rails.logger = @orig_logger
    LogStruct.config.error_handling_modes.standard_errors = @orig_standard_errors
  end

  test "a failed delivery is one error line" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report

    with_reports_recorded do
      assert_raises(DeliveryFailed) { ActionMailer::MessageDelivery.new(FailingMailer, :notice).deliver_now }
    end

    assert_equal 1, error_lines.size
    assert_equal 1, @reported.size
  end

  test "the error line names the mail's recipients, and doesn't promise a retry" do
    with_reports_recorded do
      assert_raises(DeliveryFailed) { ActionMailer::MessageDelivery.new(FailingMailer, :notice).deliver_now }
    end

    message = error_lines.first&.fetch("msg")

    assert_match(/\ADeliveryFailed: Email delivery failed\. Recipients: \[EMAIL:\h+\]\. Error message: Invalid 'From' address\z/,
      message.to_s.delete_prefix("#{self.class}::"))
  end

  # Raise is the default mode for standard errors: LogStruct raises the error instead of reporting it, and the app's
  # error reporter gets it from the job or the request
  test "in Raise mode, a failed delivery in MailDeliveryJob is one error line from the mailer" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Raise

    assert_raises(DeliveryFailed) { deliver_through_job(FailingMailer) }

    assert_equal [[FailingMailer.name, "notice"]], error_lines.map { |line| [line["mailer"], line["mailer_action"]] }
  end

  test "in Report mode, a failed delivery in MailDeliveryJob is logged and reported once" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    reported = []

    LogStruct::MultiErrorReporter.stub(:report_error, ->(error, _context) { reported << error }) do
      assert_raises(DeliveryFailed) { deliver_through_job(FailingMailer) }
    end

    assert_equal 1, error_lines.size
    assert_equal 1, reported.size
  end

  test "in Report mode, the mailer class logs and reports an error once" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    error = DeliveryFailed.new("Couldn't load the email's record")
    reported = []

    LogStruct::MultiErrorReporter.stub(:report_error, ->(e, _context) { reported << e }) do
      assert_raises(DeliveryFailed) { FailingMailer.handle_exception(error) }
    end

    assert_equal 1, error_lines.size
    assert_equal [error], reported
  end

  test "a failed delivery in MailDeliveryJob raises the delivery error, logged and reported only by the mailer" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report

    with_reports_recorded do
      assert_raises(DeliveryFailed) { ActionMailer::MessageDelivery.new(FailingMailer, :notice).deliver_now }
    end
    lines_from_mailer = error_lines.size
    reports_from_mailer = @reported.size
    @buf.truncate(0)
    @buf.rewind
    @reported.clear

    error = with_reports_recorded do
      assert_raises(DeliveryFailed) { deliver_through_job(FailingMailer) }
    end

    assert_equal "Invalid 'From' address", error.message
    assert_equal lines_from_mailer, error_lines.size, "The mailer class logged the error again"
    assert_equal reports_from_mailer, @reported.size, "The mailer class reported the error again"
  end

  test "a mailer's own rescue_from handler works in MailDeliveryJob" do
    with_reports_recorded { deliver_through_job(IgnoringMailer) }

    assert_empty @reported
    assert_equal [[IgnoringMailer.name, "notice"]], error_lines.map { |line| [line["mailer"], line["mailer_action"]] }
  end

  test "the mailer class logs, reports and re-raises an error its mailer didn't handle" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    error = DeliveryFailed.new("Couldn't load the email's record")

    with_reports_recorded do
      assert_raises(DeliveryFailed) { FailingMailer.handle_exception(error) }
    end

    assert_equal [error], @reported
    assert_equal 1, error_lines.size
    assert_match(/FailingMailer\z/, error_lines.first["mailer"])
  end

  test "the mailer class logs an error its rescue_from handler ignores, without raising" do
    with_reports_recorded { IgnoringMailer.handle_exception(DeliveryFailed.new("Couldn't load the email's record")) }

    assert_empty @reported
    assert_equal 1, error_lines.size
  end

  test "log_and_report_error logs and reports the error, and doesn't raise it, in every mode" do
    LogStruct::ErrorHandlingMode.values.each do |mode|
      LogStruct.config.error_handling_modes.standard_errors = mode
      @buf.truncate(0)
      @buf.rewind
      @reported.clear

      with_reports_recorded do
        ActionMailer::MessageDelivery.new(ReportingMailer, :notice).deliver_now
        deliver_through_job(ReportingMailer)
        ReportingMailer.handle_exception(DeliveryFailed.new("Couldn't load the email's record"))
      end

      assert_equal 3, error_lines.size, "One line per error in #{mode.serialize}"
      assert_equal 3, @reported.size, "One report per error in #{mode.serialize}"
    end
  end

  test "log_and_reraise_error reports the error only in the Report modes, and always raises it" do
    # ReportProduction reports in production only
    reports_by_mode = {
      LogStruct::ErrorHandlingMode::Raise => 0,
      LogStruct::ErrorHandlingMode::Log => 0,
      LogStruct::ErrorHandlingMode::Ignore => 0,
      LogStruct::ErrorHandlingMode::Report => 1,
      LogStruct::ErrorHandlingMode::ReportProduction => 0
    }
    reports_by_mode.each do |mode, reports|
      LogStruct.config.error_handling_modes.standard_errors = mode
      @reported.clear

      with_reports_recorded do
        assert_raises(DeliveryFailed) { ActionMailer::MessageDelivery.new(FailingMailer, :notice).deliver_now }
      end

      assert_equal reports, @reported.size, "Reports in #{mode.serialize}"
    end

    LogStruct.stub(:is_production?, true) { assert_predicate LogStruct::Integrations::ActionMailer::ErrorHandling, :report_before_reraise? }
  end

  test "a reporter that raises doesn't change what the handlers do with the error" do
    LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
    saved_handler = LogStruct.config.error_reporting_handler
    LogStruct.config.error_reporting_handler = ->(_error, _context, _source) { raise Timeout::Error, "reporter timed out" }

    ActionMailer::MessageDelivery.new(ReportingMailer, :notice).deliver_now
    ReportingMailer.handle_exception(DeliveryFailed.new("Couldn't load the email's record"))
    error = assert_raises(DeliveryFailed) { ActionMailer::MessageDelivery.new(FailingMailer, :notice).deliver_now }

    assert_equal "Invalid 'From' address", error.message
  ensure
    LogStruct.config.error_reporting_handler = saved_handler
  end

  # Only the mailer's own handler marks an error for the class handler to raise again
  test "the class handler ignores an error each time it's given it" do
    error = DeliveryFailed.new("Couldn't load the email's record")

    2.times { IgnoringMailer.handle_exception(error) }

    assert_equal 2, error_lines.size
  end

  test "the mailer's handlers log their errors as error entries" do
    entries = []
    subscription = ActiveSupport::Notifications.subscribe("log.logstruct") { |_name, _start, _finish, _id, payload| entries << payload[:log] }
    LogStruct::SemanticLogger::Logger.new("Mailer").then { |logger| ::Rails.logger = logger }

    with_reports_recorded { ActionMailer::MessageDelivery.new(IgnoringMailer, :notice).deliver_now }
    IgnoringMailer.handle_exception(DeliveryFailed.new("Couldn't load the email's record"))

    assert_equal [LogStruct::Level::Error, LogStruct::Level::Error], entries.grep(LogStruct::Log::ActionMailer::Error).map(&:level)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  private

  def deliver_through_job(mailer_class)
    ActionMailer::MailDeliveryJob.perform_now(mailer_class.name, "notice", "deliver_now", args: [])
  end

  # Records what LogStruct reports
  def with_reports_recorded(&block)
    LogStruct.stub(:report_error, ->(error, source:, context: nil) { @reported << error }, &block)
  end

  def error_lines
    @buf.string.lines.map { |line| JSON.parse(line) }.select { |line| line["src"] == "mailer" && line["evt"] == "error" }
  end
end
