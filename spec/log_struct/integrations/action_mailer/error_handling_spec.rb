# typed: false
# frozen_string_literal: true

require "spec_helper"

module LogStruct
  module Integrations::ActionMailer
    RSpec.describe ErrorHandling do
      # Define a test mailer class that inherits from ::ActionMailer::Base
      let(:test_mailer_class) do
        Class.new(::ActionMailer::Base) do
          # We need to include the module to test it
          include Integrations::ActionMailer::ErrorHandling

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

          attr_reader :mail

          def message
            mail
          end
        end
      end

      # Define custom error classes for testing
      before(:all) do
        # Define a custom delivery error class
        class DeliveryError < StandardError; end

        # Define a custom inactive recipient error class with recipients
        class InactiveRecipientError < StandardError
          attr_reader :recipients

          def initialize(message, recipients)
            super(message)
            @recipients = recipients
          end
        end
      end

      let(:mailer) { test_mailer_class.new.welcome_email }
      let(:standard_error) { StandardError.new("Standard error message") }
      let(:delivery_error) { DeliveryError.new("Delivery error") }
      let(:inactive_recipient_error) { InactiveRecipientError.new("Inactive recipient", ["inactive@example.com"]) }

      before do
        # Mock the logger methods
        allow(Integrations::ActionMailer::Logger).to receive(:log_structured_error)
        allow(Rails.logger).to receive(:info)
        allow(MultiErrorReporter).to receive(:report_exception)

        # Add rescue handlers for our custom error classes
        test_mailer_class.rescue_from(DeliveryError, with: :log_and_reraise_error)
        test_mailer_class.rescue_from(InactiveRecipientError, with: :log_and_notify_error)
      end

      describe "rescue handlers" do
        it "registers rescue handlers for different error types" do
          handlers = test_mailer_class.rescue_handlers

          # Check for handlers by name and method
          expect(handlers).to include(["StandardError", :log_and_reraise_error])
          expect(handlers).to include(["LogStruct::Integrations::ActionMailer::DeliveryError", :log_and_reraise_error])
          expect(handlers).to include(["LogStruct::Integrations::ActionMailer::InactiveRecipientError", :log_and_notify_error])
        end
      end

      describe "#log_and_ignore_error" do
        it "logs the error but does not raise it" do
          expect(mailer).to receive(:log_email_delivery_error).with(inactive_recipient_error,
            notify: false,
            report: false,
            reraise: false).and_call_original
          allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

          # Should not raise an error
          expect { mailer.send(:log_and_ignore_error, inactive_recipient_error) }.not_to raise_error
        end
      end

      describe "#log_and_notify_error" do
        it "logs the error with notify flag and does not raise it" do
          expect(mailer).to receive(:log_email_delivery_error).with(standard_error,
            notify: true,
            report: false,
            reraise: false).and_call_original
          allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

          # Should not raise an error
          expect { mailer.send(:log_and_notify_error, standard_error) }.not_to raise_error
        end
      end

      describe "#log_and_report_error" do
        it "logs the error with report flag and does not raise it" do
          expect(mailer).to receive(:log_email_delivery_error).with(standard_error,
            notify: false,
            report: true,
            reraise: false).and_call_original
          allow(mailer).to receive(:handle_error_notifications) # Stub this to prevent actual error handling

          # Should not raise an error
          expect { mailer.send(:log_and_report_error, standard_error) }.not_to raise_error
        end
      end

      describe "#log_and_reraise_error" do
        it "logs the error and reraises it" do
          expect(mailer).to receive(:log_email_delivery_error).with(standard_error,
            notify: false,
            report: true,
            reraise: true).and_call_original

          # We need to allow handle_error_notifications to be called and actually reraise the error
          expect(mailer).to receive(:handle_error_notifications).with(standard_error, false, true, true).and_call_original

          # Should raise the error
          expect do
            mailer.send(:log_and_reraise_error, standard_error)
          end.to raise_error(StandardError, "Standard error message")
        end
      end

      describe "#log_email_delivery_error" do
        context "with standard error" do
          it "logs the error and handles notifications" do
            expect(mailer).to receive(:error_message_for).with(standard_error, true).and_call_original
            expect(Integrations::ActionMailer::Logger).to receive(:log_structured_error)
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
            expect(MultiErrorReporter).to receive(:report_exception).with(
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
            expect do
              mailer.send(:handle_error_notifications, standard_error, false, false, true)
            end.to raise_error(StandardError, "Standard error message")
          end
        end
      end

      describe "#log_notification_event" do
        it "logs a notification with structured data" do
          expect(Log::Exception).to receive(:from_exception).with(
            LogSource::Mailer,
            LogEvent::Error,
            standard_error,
            hash_including(
              mailer: mailer.class,
              action: "test_email"
            )
          ).and_call_original
          expect(Rails.logger).to receive(:info)

          mailer.send(:log_notification_event, standard_error)
        end
      end

      describe "#recipients" do
        it "extracts recipients from error if available" do
          recipients = mailer.send(:recipients, inactive_recipient_error)
          expect(recipients).to eq("inactive@example.com")
        end

        it "returns 'unknown' if error does not respond to recipients" do
          recipients = mailer.send(:recipients, standard_error)
          expect(recipients).to eq("unknown")
        end
      end
    end
  end
end
