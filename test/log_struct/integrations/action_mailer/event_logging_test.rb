# typed: true
# frozen_string_literal: true

require "test_helper"
require "action_mailer"

class ActionMailerEventLoggingTest < ActiveSupport::TestCase
  EventLogging = LogStruct::Integrations::ActionMailer::EventLogging
  Callbacks = LogStruct::Integrations::ActionMailer::Callbacks

  DummyMessage = Struct.new(:to, :cc, :bcc, :attachments, :subject, :from, :message_id)

  class DummyMailer < ActionMailer::Base
    include Callbacks
    include EventLogging

    def initialize(msg)
      super()
      @__msg = msg
    end

    def message = @__msg

    def action_name = "sample"
  end

  setup do
    @msg = DummyMessage.new(%w[a@b.com], nil, %w[x@y.com], [], "Welcome", ["noreply@example.com"], "m-1")
    @mailer = DummyMailer.new(@msg)
    # Capture logs as JSON
    @orig_logger = ::Rails.logger
    @buf = StringIO.new
    logger = ::Logger.new(@buf)
    logger.formatter = LogStruct::Formatter.new
    ::Rails.logger = logger
  end

  teardown do
    ::Rails.logger = @orig_logger
  end

  test "log_email_delivery builds ActionMailer log with Delivery event" do
    @mailer.send(:log_email_delivery)
    parsed = JSON.parse(@buf.string)

    assert_equal "mailer", parsed["src"]
    assert_equal "delivery", parsed["evt"]
    assert_kind_of Array, parsed["to"]
    assert_match(/\[EMAIL:/, parsed["to"].first)
    assert_match(/\[EMAIL:/, parsed["from"])
    assert_equal "Welcome", parsed["subject"]
    assert_match(/DummyMailer\z/, parsed["mailer_class"])
    assert_equal "sample", parsed["mailer_action"]
    assert_equal "m-1", parsed["message_id"]
  end

  test "log_email_delivered builds ActionMailer log with Delivered event" do
    @mailer.send(:log_email_delivered)
    parsed = JSON.parse(@buf.string)

    assert_equal "delivered", parsed["evt"]
  end
end
