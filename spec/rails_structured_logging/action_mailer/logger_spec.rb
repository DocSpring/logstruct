# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsStructuredLogging::ActionMailer::Logger do
  let(:message) { double("Mail::Message", message_id: "test-message-id") }
  let(:mailer) do
    double(
      "TestMailer",
      message: message,
      class: double("Class", name: "TestMailer"),
      action_name: "welcome_email"
    )
  end
  let(:rails_logger) { double("Rails.logger") }

  before do
    allow(RailsStructuredLogging::ActionMailer::MetadataCollection).to receive(:add_message_metadata)
    allow(RailsStructuredLogging::ActionMailer::MetadataCollection).to receive(:add_context_metadata)
    allow(Rails).to receive(:logger).and_return(rails_logger)
    allow(rails_logger).to receive(:info)
    allow(rails_logger).to receive(:error)
    allow(rails_logger).to receive(:debug)
  end

  describe ".build_base_log_data" do
    it "builds base log data with correct structure" do
      test_time = Time.new(2023, 1, 1, 12, 0, 0)
      allow(Time).to receive(:current).and_return(test_time)

      log_data = described_class.build_base_log_data(mailer, "test_event")

      expect(log_data[:src]).to eq("mailer")
      expect(log_data[:evt]).to eq("test_event")
      expect(log_data[:ts]).to eq(test_time.iso8601(3))
      expect(log_data[:message_id]).to eq("test-message-id")
      expect(log_data[:mailer_class]).to eq("TestMailer")
      expect(log_data[:mailer_action]).to eq("welcome_email")
    end

    it "calls metadata collection methods" do
      expect(RailsStructuredLogging::ActionMailer::MetadataCollection).to receive(:add_message_metadata)
      expect(RailsStructuredLogging::ActionMailer::MetadataCollection).to receive(:add_context_metadata)

      described_class.build_base_log_data(mailer, "test_event")
    end
  end

  describe ".log_structured_error" do
    let(:error) { StandardError.new("Test error") }
    let(:message) { "Error message for logging" }

    it "logs structured error information" do
      expect(described_class).to receive(:build_base_log_data).with(mailer, "email_error").and_call_original
      expect(described_class).to receive(:log_to_rails).with(kind_of(Hash), :error)

      described_class.log_structured_error(mailer, error, message)
    end

    it "includes error information in log data" do
      allow(described_class).to receive(:log_to_rails) do |log_data, level|
        expect(level).to eq(:error)
        expect(log_data[:error_class]).to eq("StandardError")
        expect(log_data[:error_message]).to eq("Test error")
        expect(log_data[:msg]).to eq("Error message for logging")
      end

      described_class.log_structured_error(mailer, error, message)
    end
  end

  describe ".log_to_rails" do
    it "sends log message to Rails logger with correct level" do
      described_class.log_to_rails("test message", :info)
      expect(rails_logger).to have_received(:info).with("test message")

      described_class.log_to_rails("error message", :error)
      expect(rails_logger).to have_received(:error).with("error message")

      described_class.log_to_rails({key: "value"}, :debug)
      expect(rails_logger).to have_received(:debug).with({key: "value"})
    end
  end
end
