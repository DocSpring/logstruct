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

  setup do
    @orig_logger = ::Rails.logger
    @buf = StringIO.new
    logger = ::Logger.new(@buf)
    logger.formatter = LogStruct::Formatter.new
    ::Rails.logger = logger
    @reported = []
  end

  teardown do
    ::Rails.logger = @orig_logger
  end

  test "a failed delivery in MailDeliveryJob raises the delivery error, logged and reported only by the mailer" do
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

  private

  def deliver_through_job(mailer_class)
    ActionMailer::MailDeliveryJob.perform_now(mailer_class.name, "notice", "deliver_now", args: [])
  end

  # LogStruct.handle_exception raises in tests; record what it would report in production
  def with_reports_recorded(&block)
    LogStruct.stub(:handle_exception, ->(error, source:, context: nil) { @reported << error }, &block)
  end

  def error_lines
    @buf.string.lines.map { |line| JSON.parse(line) }.select { |line| line["src"] == "mailer" && line["evt"] == "error" }
  end
end
