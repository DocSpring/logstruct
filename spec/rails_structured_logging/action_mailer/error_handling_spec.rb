# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_mailer"
require "active_support"

RSpec.describe RailsStructuredLogging::ActionMailer::ErrorHandling do
  # Define a test mailer class that inherits from ActionMailer::Base
  let(:test_mailer_class) do
    Class.new(ActionMailer::Base) do
      # We need to include the module to test it
      include RailsStructuredLogging::ActionMailer::ErrorHandling

      def self.name
        "TestMailer"
      end

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
  let(:postmark_error) { Postmark::Error.new("Postmark error") }
  let(:postmark_inactive_error) { Postmark::InactiveRecipientError.new("Inactive recipient", ["inactive@example.com"]) }

  before do
    # Mock the logger methods
    allow(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_structured_error)
    allow(Rails.logger).to receive(:info)
    allow(RailsStructuredLogging::MultiErrorReporter).to receive(:report_exception)
  end

  describe "rescue handlers" do
    it "registers rescue handlers for different error types" do
      handlers = test_mailer_class.rescue_handlers

      # Check for handlers by name and method
      expect(handlers).to include(["StandardError", :log_and_reraise_error])
      expect(handlers).to include(["Postmark::Error", :log_and_reraise_error])
      expect(handlers).to include(["Postmark::InactiveRecipientError", :log_and_notify_error])
      expect(handlers).to include(["Postmark::InvalidEmailRequestError", :log_and_notify_error])
    end
  end

  describe "#log_and_ignore_error" do
    it "logs the error but does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(postmark_inactive_error, notify: false, report: false, reraise: false).and_call_original
      allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

      # Should not raise an error
      expect { mailer.send(:log_and_ignore_error, postmark_inactive_error) }.not_to raise_error
    end
  end

  describe "#log_and_notify_error" do
    it "logs the error with notify flag and does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: true, report: false, reraise: false).and_call_original
      allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

      # Should not raise an error
      expect { mailer.send(:log_and_notify_error, standard_error) }.not_to raise_error
    end
  end

  describe "#log_and_report_error" do
    it "logs the error with report flag and does not raise it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: false, report: true, reraise: false).and_call_original
      allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

      # Should not raise an error
      expect { mailer.send(:log_and_report_error, standard_error) }.not_to raise_error
    end
  end

  describe "#log_and_reraise_error" do
    it "logs the error and reraises it" do
      expect(mailer).to receive(:log_email_delivery_error).with(standard_error, notify: false, report: true, reraise: true).and_call_original

      # We need to allow handle_error_notifications to be called and actually reraise the error
      expect(mailer).to receive(:handle_error_notifications).with(standard_error, false, true, true).and_call_original

      # Should raise the error
      expect { mailer.send(:log_and_reraise_error, standard_error) }.to raise_error(StandardError, "Standard error message")
    end
  end

  describe "#log_email_delivery_error" do
    context "with standard error" do
      it "logs the error and handles notifications" do
        expect(mailer).to receive(:error_message_for).with(standard_error, true).and_call_original
        expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_structured_error)
        expect(mailer).to receive(:handle_error_notifications).with(standard_error, false, true, true)

        mailer.send(:log_email_delivery_error, standard_error)
      end
    end
  end

  describe "#error_message_for" do
    before do
      allow(mailer).to receive(:recipients).and_return("test@example.com")
    end

    context "when reraise is true" do
      it "returns retry message" do
        message = mailer.send(:error_message_for, standard_error, true)
        expect(message).to include("will retry")
        expect(message).to include("test@example.com")
      end
    end

    context "when reraise is false" do
      it "returns cannot send message" do
        message = mailer.send(:error_message_for, standard_error, false)
        expect(message).to include("Cannot send email")
        expect(message).to include("test@example.com")
      end
    end
  end

  describe "#handle_error_notifications" do
    context "when notify is true" do
      it "logs a notification event" do
        expect(mailer).to receive(:log_notification_event).with(standard_error)
        mailer.send(:handle_error_notifications, standard_error, true, false, false)
      end
    end

    context "when report is true" do
      it "reports to error reporting service" do
        expect(RailsStructuredLogging::MultiErrorReporter).to receive(:report_exception).with(
          standard_error,
          hash_including(
            mailer_class: "TestMailer",
            recipients: "unknown"
          )
        )
        mailer.send(:handle_error_notifications, standard_error, false, true, false)
      end
    end

    context "when reraise is true" do
      it "reraises the error" do
        expect {
          mailer.send(:handle_error_notifications, standard_error, false, false, true)
        }.to raise_error(StandardError, "Standard error message")
      end
    end
  end

  describe "#log_notification_event" do
    it "logs a notification with structured data" do
      expect(RailsStructuredLogging::LogTypes).to receive(:create_email_notification_log_data).with(standard_error, mailer).and_call_original
      expect(Rails.logger).to receive(:info)

      mailer.send(:log_notification_event, standard_error)
    end
  end

  describe "#recipients" do
    it "extracts recipients from error if available" do
      recipients = mailer.send(:recipients, postmark_inactive_error)
      expect(recipients).to eq("inactive@example.com")
    end

    it "returns 'unknown' if error does not respond to recipients" do
      recipients = mailer.send(:recipients, standard_error)
      expect(recipients).to eq("unknown")
    end
  end
end
