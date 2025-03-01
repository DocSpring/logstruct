# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsStructuredLogging::ActionMailer::ErrorHandling do
  # Define a test mailer class that includes the ErrorHandling module
  let(:test_mailer_class) do
    Class.new do
      def self.name
        "TestMailer"
      end

      def self.rescue_from(error_class, options = {})
        @rescue_handlers ||= []
        @rescue_handlers << [error_class, options]
      end

      def self.rescue_handlers
        @rescue_handlers || []
      end

      include RailsStructuredLogging::ActionMailer::ErrorHandling

      def welcome_email
        @mail = OpenStruct.new(
          to: ["user@example.com"],
          cc: ["cc@example.com"],
          bcc: ["bcc@example.com"],
          from: ["from@example.com"],
          subject: "Welcome Email",
          message_id: "<123@example.com>"
        )
        self
      end

      def mail
        @mail
      end

      def message
        mail
      end
    end
  end

  let(:mailer) { test_mailer_class.new.welcome_email }
  let(:standard_error) { StandardError.new("Standard error message") }
  let(:postmark_inactive_error) do
    Class.new(StandardError) do
      def self.name
        "Postmark::InactiveRecipientError"
      end

      def recipients
        ["inactive@example.com"]
      end
    end.new("Inactive recipient")
  end

  describe "rescue handlers" do
    it "registers rescue handlers for different error types" do
      handlers = test_mailer_class.rescue_handlers

      # Check StandardError handler
      standard_handler = handlers.find { |h| h[0] == StandardError }
      expect(standard_handler).not_to be_nil
      expect(standard_handler[1][:with]).to eq(:log_and_reraise_error)

      # Check for Postmark error handlers
      postmark_inactive_handler = handlers.find { |h| h[0].to_s == "Postmark::InactiveRecipientError" }
      expect(postmark_inactive_handler).not_to be_nil
      expect(postmark_inactive_handler[1][:with]).to eq(:log_and_ignore_error)

      postmark_invalid_handler = handlers.find { |h| h[0].to_s == "Postmark::InvalidEmailRequestError" }
      expect(postmark_invalid_handler).not_to be_nil
      expect(postmark_invalid_handler[1][:with]).to eq(:log_and_notify_error)
    end
  end

  describe "#log_and_ignore_error" do
    it "logs the error but does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(postmark_inactive_error, notify: false, report: false)

      # Should not raise an error
      expect { mailer.log_and_ignore_error(postmark_inactive_error) }.not_to raise_error
    end
  end

  describe "#log_and_notify_error" do
    it "logs the error with notify flag and does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: true, report: false)

      # Should not raise an error
      expect { mailer.log_and_notify_error(standard_error) }.not_to raise_error
    end
  end

  describe "#log_and_report_error" do
    it "logs the error with report flag and does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: false, report: true)

      # Should not raise an error
      expect { mailer.log_and_report_error(standard_error) }.not_to raise_error
    end
  end

  describe "#log_and_reraise_error" do
    it "logs the error and reraises it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: false, report: true)

      # Should raise the error
      expect { mailer.log_and_reraise_error(standard_error) }.to raise_error(StandardError, "Standard error message")
    end
  end

  describe "#log_email_delivery_error" do
    before do
      allow(RailsStructuredLogging::Logger).to receive(:log)
    end

    it "logs error with email_error event" do
      expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
        expect(level).to eq(:error)
        expect(data[:event]).to eq("email_error")
        expect(data[:error_class]).to eq("StandardError")
        expect(data[:error_message]).to eq("Standard error message")
        expect(data[:mailer]).to eq("TestMailer")
        expect(data[:to]).to eq(["user@example.com"])
      end

      mailer.send(:log_email_delivery_error, standard_error)
    end

    it "includes recipient information from error if available" do
      expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
        expect(data[:recipients]).to eq(["inactive@example.com"])
      end

      mailer.send(:log_email_delivery_error, postmark_inactive_error)
    end

    context "when notify is true" do
      it "includes notification information in the log" do
        expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
          expect(data[:notify]).to eq(true)
        end

        mailer.send(:log_email_delivery_error, standard_error, notify: true)
      end
    end

    context "when report is true" do
      it "includes report information in the log" do
        expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
          expect(data[:report]).to eq(true)
        end

        mailer.send(:log_email_delivery_error, standard_error, report: true)
      end
    end
  end

  describe "#recipients" do
    it "extracts recipients from error if available" do
      recipients = mailer.send(:recipients, postmark_inactive_error)
      expect(recipients).to eq(["inactive@example.com"])
    end

    it "returns nil if error does not respond to recipients" do
      recipients = mailer.send(:recipients, standard_error)
      expect(recipients).to be_nil
    end
  end
end
