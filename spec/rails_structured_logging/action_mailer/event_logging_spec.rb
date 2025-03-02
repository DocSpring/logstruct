# typed: false
# frozen_string_literal: true

require "spec_helper"
require "rails"
require "action_mailer"
require "active_support"

RSpec.describe RailsStructuredLogging::ActionMailer::EventLogging do
  # Create a test mailer class that inherits from ::ActionMailer::Base
  let(:test_mailer_class) do
    Class.new(ActionMailer::Base) do
      include RailsStructuredLogging::ActionMailer::EventLogging

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

  let(:mailer) { test_mailer_class.new.welcome_email }

  before do
    allow(RailsStructuredLogging::ActionMailer::Logger).to receive(:build_base_log_data).and_return({})
    allow(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_to_rails)
  end

  describe "callbacks" do
    it "registers before_deliver callback" do
      callbacks = test_mailer_class._callback_runner_callbacks[:deliver].select { |cb| cb.kind == :before }
      expect(callbacks.map(&:filter)).to include(:log_email_delivery)
    end

    it "registers after_deliver callback" do
      callbacks = test_mailer_class._callback_runner_callbacks[:deliver].select { |cb| cb.kind == :after }
      expect(callbacks.map(&:filter)).to include(:log_email_delivered)
    end
  end

  describe "#log_email_delivery" do
    it "logs email delivery event" do
      expect(mailer).to receive(:log_mailer_event).with("email_delivery")
      mailer.send(:log_email_delivery)
    end
  end

  describe "#log_email_delivered" do
    it "logs email delivered event" do
      expect(mailer).to receive(:log_mailer_event).with("email_delivered")
      mailer.send(:log_email_delivered)
    end
  end

  describe "#log_mailer_event" do
    it "logs event with base data" do
      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:build_base_log_data)
        .with(mailer, "test_event")
        .and_return({base: "data"})

      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_to_rails)
        .with({base: "data"}, :info)

      result = mailer.send(:log_mailer_event, "test_event")
      expect(result).to eq({base: "data"})
    end

    it "merges additional data when provided" do
      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:build_base_log_data)
        .with(mailer, "test_event")
        .and_return({base: "data"})

      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_to_rails)
        .with({base: "data", additional: "value"}, :info)

      result = mailer.send(:log_mailer_event, "test_event", :info, {additional: "value"})
      expect(result).to eq({base: "data", additional: "value"})
    end

    it "uses the specified log level" do
      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:build_base_log_data)
        .with(mailer, "test_event")
        .and_return({base: "data"})

      expect(RailsStructuredLogging::ActionMailer::Logger).to receive(:log_to_rails)
        .with({base: "data"}, :debug)

      mailer.send(:log_mailer_event, "test_event", :debug)
    end
  end
end
