# typed: true
# frozen_string_literal: true

require "test_helper"
require "active_job"
require "action_mailer"

module LogStruct
  module CodeExamples
    # The code shown on the guides (docs/app/docs/guides/*) and the SOC 2 page
    class GuidesTest < ActiveSupport::TestCase
      # Stand-ins for the postmark gem's errors (lib/postmark/error.rb in postmark 1.25), which
      # LogStruct doesn't depend on. InactiveRecipientError has the addresses Postmark refused.
      module Postmark
        class Error < StandardError; end

        class ApiInputError < Error; end

        class InvalidEmailRequestError < ApiInputError; end

        class InactiveRecipientError < ApiInputError
          attr_reader :recipients

          def initialize(message, recipients)
            super(message)
            @recipients = recipients
          end
        end
      end

      # Raises the error a test sets, like Postmark's API refusing a mail
      class PostmarkDelivery
        class << self
          attr_accessor :error
        end

        def initialize(_settings)
        end

        def deliver!(_mail)
          raise T.must(self.class.error)
        end
      end
      ::ActionMailer::Base.add_delivery_method :guides_postmark, PostmarkDelivery

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: postmark_rescue_from
      # ----------------------------------------------------------
      class ApplicationMailer < ActionMailer::Base
        # Postmark won't send to these addresses, and sending again won't change that.
        # Log the error and carry on as if the mail had been sent.
        rescue_from Postmark::InactiveRecipientError,
          Postmark::InvalidEmailRequestError,
          with: :log_and_ignore_error

        # Every other StandardError reaches LogStruct's default handler, log_and_reraise_error
      end
      # ----------------------------------------------------------
      # END CODE EXAMPLE: postmark_rescue_from
      # ----------------------------------------------------------

      class InvoiceMailer < ApplicationMailer
        default from: "billing@example.com"
        self.delivery_method = :guides_postmark

        def invoice_ready(email)
          mail(to: email, subject: "Your invoice is ready", body: "Your invoice is ready.")
        end
      end

      # The app's own job that posts to Slack
      class SlackAlertJob < ::ActiveJob::Base
        def perform(channel:, text:)
        end
      end

      INACTIVE_MESSAGE = "You tried to send to recipient(s) that have been marked as inactive. " \
        "Found inactive addresses: jo@example.com. Inactive recipients are ones that have " \
        "generated a hard bounce, a spam complaint, or a manual suppression."

      setup do
        @io = setup_isolated_logger
        @reported = []
        reported = @reported
        LogStruct.config.error_reporting_handler = ->(error, _context, source) { reported << [error.class, source] }
        @saved_mail_job_adapter = ::ActionMailer::MailDeliveryJob._queue_adapter
        @saved_slack_job_adapter = SlackAlertJob._queue_adapter
        @listeners_before = ::ActiveSupport::Notifications.notifier.listeners_for("log.logstruct")
      end

      teardown do
        (::ActiveSupport::Notifications.notifier.listeners_for("log.logstruct") - @listeners_before).each do |listener|
          ::ActiveSupport::Notifications.unsubscribe(listener)
        end
        ::ActionMailer::MailDeliveryJob._queue_adapter = @saved_mail_job_adapter
        SlackAlertJob._queue_adapter = @saved_slack_job_adapter
        PostmarkDelivery.error = nil
        teardown_isolated_logger
      end

      def test_postmark_rescue_from
        # The default mode for standard errors, in which log_and_reraise_error raises without reporting
        assert_equal ErrorHandlingMode::Raise, LogStruct.config.error_handling_modes.standard_errors
        assert_includes ::ActionMailer::Base.rescue_handlers, ["StandardError", :log_and_reraise_error]

        # An inactive recipient: one error line, nothing raised or reported, no delivered line
        PostmarkDelivery.error = Postmark::InactiveRecipientError.new(INACTIVE_MESSAGE, ["jo@example.com"])
        invoice_ready("jo@example.com").deliver_now

        lines = mailer_lines

        assert_equal %w[delivery error], lines.map { |line| line["evt"] }
        error_line = T.must(lines.last)

        assert_equal Postmark::InactiveRecipientError.name, error_line["error_class"]
        assert_equal InvoiceMailer.name, error_line["mailer"]
        assert_match(/\A#{Regexp.escape(Postmark::InactiveRecipientError.name.to_s)}: Cannot send email to \[EMAIL:\h+\]\. Error message: /, error_line["msg"])
        refute_includes @io.string, "jo@example.com"
        assert_empty @reported

        # An invalid request is handled the same way
        PostmarkDelivery.error = Postmark::InvalidEmailRequestError.new("Error parsing 'To': Illegal email address 'jo@example'.")
        invoice_ready("jo@example").deliver_now

        assert_equal %w[delivery error], mailer_lines.map { |line| line["evt"] }

        # deliver_later: the delivery job succeeds
        ::ActionMailer::MailDeliveryJob.queue_adapter = :inline
        PostmarkDelivery.error = Postmark::InactiveRecipientError.new(INACTIVE_MESSAGE, ["jo@example.com"])
        invoice_ready("jo@example.com").deliver_later

        assert_equal %w[delivery error], mailer_lines.map { |line| line["evt"] }

        # Other errors reach the default handler, which logs and raises them (Raise mode)
        PostmarkDelivery.error = Errno::ECONNREFUSED.new("connect(2) for smtp.example.com port 443")
        assert_raises(Errno::ECONNREFUSED) { invoice_ready("jo@example.com").deliver_now }
        error_line = T.must(mailer_lines.last)

        assert_match(/\AErrno::ECONNREFUSED: Email delivery failed\. Recipients: \[EMAIL:\h+\]\. Error message: /, error_line["msg"])
        assert_empty @reported

        # In Report mode, the default handler reports them before raising them
        LogStruct.config.error_handling_modes.standard_errors = ErrorHandlingMode::Report
        assert_raises(Errno::ECONNREFUSED) { invoice_ready("jo@example.com").deliver_now }
        assert_equal [[Errno::ECONNREFUSED, Source::Mailer]], @reported
      end

      def test_postmark_slack_alerts
        SlackAlertJob.queue_adapter = :test

        # What a subscriber gets, to show what the example leaves out
        logged = []
        ::ActiveSupport::Notifications.subscribe("log.logstruct") { |_name, _start, _finish, _id, payload| logged << payload[:log] }

        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: postmark_slack_alerts
        # ----------------------------------------------------------
        ActiveSupport::Notifications.subscribe("log.logstruct") do |_name, _start, _finish, _id, payload|
          log = payload[:log]
          next unless log.is_a?(LogStruct::Log::ActionMailer::Error)
          next unless [Postmark::InactiveRecipientError, Postmark::InvalidEmailRequestError].include?(log.error_class)

          # This is the log entry before LogStruct filtered it: its message, to and subject
          # can hold the recipients' addresses. Send only the mailer and the error class.
          SlackAlertJob.perform_later(
            channel: "#email-alerts",
            text: "#{log.mailer_class} couldn't send a mail: #{log.error_class.name}"
          )
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: postmark_slack_alerts
        # ----------------------------------------------------------

        PostmarkDelivery.error = Postmark::InactiveRecipientError.new(INACTIVE_MESSAGE, ["jo@example.com"])
        invoice_ready("jo@example.com").deliver_now

        # One alert for the failed mail, without the address
        alerts = slack_alerts

        assert_equal [{channel: "#email-alerts", text: "#{InvoiceMailer.name} couldn't send a mail: #{Postmark::InactiveRecipientError.name}"}], alerts
        refute_includes alerts.inspect, "jo@example.com"

        # The entry a subscriber gets isn't filtered; the line LogStruct writes is
        entry = logged.find { |log| log.is_a?(Log::ActionMailer::Error) }

        assert_equal ["jo@example.com"], entry.to
        assert_includes entry.message, "jo@example.com"
        assert_includes T.must(mailer_lines.last)["msg"], "[EMAIL:"
        refute_includes @io.string, "jo@example.com"

        # Other errors send no alert
        SlackAlertJob.queue_adapter.enqueued_jobs.clear
        PostmarkDelivery.error = Errno::ECONNREFUSED.new("connect(2) for smtp.example.com port 443")
        assert_raises(Errno::ECONNREFUSED) { invoice_ready("jo@example.com").deliver_now }
        assert_empty slack_alerts
      end

      def test_soc2_filtered_line
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: soc2_filtered_line
        # ----------------------------------------------------------
        Rails.logger.info(
          msg: "Password reset requested",
          email: "Jo@Example.com",
          note: "Reset link sent to jo@example.com",
          credentials: {username: "jo", password: "hunter2"},
          reset_url: "https://app.example.com/reset?token=abc123&step=2",
          card: "4111 1111 1111 1111",
          name: "Jo Smith"
        )
        # ----------------------------------------------------------
        # END CODE EXAMPLE: soc2_filtered_line
        # ----------------------------------------------------------

        ::SemanticLogger.flush
        line = JSON.parse(T.must(@io.string.lines.last))
        email_hash = line.dig("email", "_filtered", "_hash")

        assert_equal({"_class" => "String", "_hash" => email_hash}, line.dig("email", "_filtered"))
        # One hash for the address, whatever its case, under a key or inside a string
        assert_equal "Reset link sent to [EMAIL:#{email_hash}]", line["note"]
        assert_equal({"_class" => "Hash", "_keys_count" => 2, "_keys" => %w[username password]}, line.dig("credentials", "_filtered"))
        assert_equal "https://app.example.com/reset?token=[FILTERED]&step=2", line["reset_url"]
        assert_equal "[CREDIT_CARD]", line["card"]
        # Nothing matches a name, so it's logged as it is
        assert_equal "Jo Smith", line["name"]
        %w[jo@example.com Jo@Example.com hunter2 abc123 4111].each { |secret| refute_includes @io.string, secret }
      end

      private

      # Mailer actions are class methods through ActionMailer's method_missing, which Sorbet can't see
      def invoice_ready(email)
        T.unsafe(InvoiceMailer).invoice_ready(email)
      end

      # The mailer lines logged since the last call
      def mailer_lines
        ::SemanticLogger.flush
        lines = @io.string.lines.filter_map do |line|
          JSON.parse(line)
        rescue JSON::ParserError
          nil
        end
        clear_log_buffer(@io)
        lines.select { |line| line["src"] == "mailer" }
      end

      # The arguments of the SlackAlertJob jobs enqueued so far
      def slack_alerts
        SlackAlertJob.queue_adapter.enqueued_jobs.map do |job|
          ::ActiveJob::Arguments.deserialize(job[:args]).first.symbolize_keys
        end
      end
    end
  end
end
