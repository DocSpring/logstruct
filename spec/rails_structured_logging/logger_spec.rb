# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsStructuredLogging::Logger do
  let(:rails_logger) { instance_double("ActiveSupport::Logger") }

  before do
    allow(Rails).to receive(:logger).and_return(rails_logger)
    allow(rails_logger).to receive(:info)
    allow(rails_logger).to receive(:error)
    allow(rails_logger).to receive(:debug)
    allow(rails_logger).to receive(:warn)
  end

  describe ".log" do
    it "logs a hash with timestamp" do
      data = { message: "Test message" }
      expect(rails_logger).to receive(:info) do |log_data|
        expect(log_data[:message]).to eq("Test message")
        expect(log_data[:ts]).to be_present
      end

      described_class.log(data)
    end

    it "converts non-hash data to a hash" do
      expect(rails_logger).to receive(:info) do |log_data|
        expect(log_data[:message]).to eq("Test message")
      end

      described_class.log("Test message")
    end

    it "logs at the specified level" do
      data = { message: "Test message" }
      expect(rails_logger).to receive(:error).with(hash_including(message: "Test message"))

      described_class.log(data, :error)
    end
  end

  describe ".info" do
    it "logs at info level" do
      expect(described_class).to receive(:log).with({ message: "Info message" }, :info)
      described_class.info({ message: "Info message" })
    end
  end

  describe ".error" do
    it "logs at error level" do
      expect(described_class).to receive(:log).with({ message: "Error message" }, :error)
      described_class.error({ message: "Error message" })
    end
  end

  describe ".debug" do
    it "logs at debug level" do
      expect(described_class).to receive(:log).with({ message: "Debug message" }, :debug)
      described_class.debug({ message: "Debug message" })
    end
  end

  describe ".warn" do
    it "logs at warn level" do
      expect(described_class).to receive(:log).with({ message: "Warn message" }, :warn)
      described_class.warn({ message: "Warn message" })
    end
  end

  describe ".exception" do
    let(:error) { StandardError.new("Test error") }

    before do
      allow(error).to receive(:backtrace).and_return(["line1", "line2", "line3"])
    end

    it "logs exception details" do
      expect(described_class).to receive(:log) do |data, level|
        expect(level).to eq(:error)
        expect(data[:error_class]).to eq("StandardError")
        expect(data[:error_message]).to eq("Test error")
        expect(data[:backtrace]).to be_an(Array)
      end

      described_class.exception(error)
    end

    it "includes additional context" do
      context = { user_id: 123, action: "login" }

      expect(described_class).to receive(:log) do |data, level|
        expect(level).to eq(:error)
        expect(data[:user_id]).to eq(123)
        expect(data[:action]).to eq("login")
      end

      described_class.exception(error, context)
    end
  end
end
