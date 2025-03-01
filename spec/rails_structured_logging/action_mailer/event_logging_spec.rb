# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsStructuredLogging::ActionMailer::EventLogging do
  let(:test_mailer_class) do
    Class.new do
      def self.name
        "TestMailer"
      end

      def self.before_deliver(callback)
        @before_deliver_callback = callback
      end

      def self.after_deliver(callback)
        @after_deliver_callback = callback
      end

      def self.before_deliver_callback
        @before_deliver_callback
      end

      def self.after_deliver_callback
        @after_deliver_callback
      end

      include RailsStructuredLogging::ActionMailer::EventLogging

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

  describe "callbacks" do
    it "registers before_deliver callback" do
      expect(test_mailer_class.before_deliver_callback).to eq(:log_email_delivery)
    end

    it "registers after_deliver callback" do
      expect(test_mailer_class.after_deliver_callback).to eq(:log_email_delivered)
    end
  end

  describe "#log_email_delivery" do
    it "logs email delivery event" do
      expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
        expect(level).to eq(:info)
        expect(data[:event]).to eq("email_delivery")
        expect(data[:mailer]).to eq("TestMailer")
        expect(data[:to]).to eq(["user@example.com"])
        expect(data[:cc]).to eq(["cc@example.com"])
        expect(data[:bcc]).to eq(["bcc@example.com"])
        expect(data[:from]).to eq(["from@example.com"])
        expect(data[:subject]).to eq("Welcome Email")
        expect(data[:message_id]).to eq("<123@example.com>")
      end

      mailer.log_email_delivery
    end
  end

  describe "#log_email_delivered" do
    it "logs email delivered event" do
      expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
        expect(level).to eq(:info)
        expect(data[:event]).to eq("email_delivered")
        expect(data[:mailer]).to eq("TestMailer")
        expect(data[:to]).to eq(["user@example.com"])
        expect(data[:cc]).to eq(["cc@example.com"])
        expect(data[:bcc]).to eq(["bcc@example.com"])
        expect(data[:from]).to eq(["from@example.com"])
        expect(data[:subject]).to eq("Welcome Email")
        expect(data[:message_id]).to eq("<123@example.com>")
      end

      mailer.log_email_delivered
    end
  end

  describe "#log_mailer_event" do
    it "logs event with mailer data" do
      expect(RailsStructuredLogging::Logger).to receive(:log) do |data, level|
        expect(level).to eq(:info)
        expect(data[:event]).to eq("test_event")
        expect(data[:mailer]).to eq("TestMailer")
        expect(data[:to]).to eq(["user@example.com"])
        expect(data[:additional_key]).to eq("additional_value")
      end

      mailer.send(:log_mailer_event, "test_event", :info, { additional_key: "additional_value" })
    end
  end
end
