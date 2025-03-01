# typed: false
# frozen_string_literal: true

require "spec_helper"
require "sorbet-runtime"
require "rspec/sorbet"

RSpec.describe "Sorbet Type Signatures" do
  # Use T::Sig directly instead of RSpec::Sorbet::Types::Sig
  extend T::Sig

  sig { returns(T::Boolean) }
  let(:enabled) { true }

  sig { returns(T::Boolean) }
  let(:lograge_enabled) { true }

  sig { returns(String) }
  let(:logstop_email_salt) { "test_salt" }

  sig { returns(T::Boolean) }
  let(:filter_emails) { true }

  sig { returns(T::Boolean) }
  let(:filter_credit_cards) { true }

  describe "Configuration with Sorbet type signatures" do
    it "configures the gem with type-checked methods" do
      # Configure the gem directly using our let variables
      RailsStructuredLogging.configure do |config|
        config.enabled = enabled
        config.lograge_enabled = lograge_enabled
        config.logstop_email_salt = logstop_email_salt
        config.filter_emails = filter_emails
        config.filter_credit_cards = filter_credit_cards
      end

      # Verify configuration was applied
      expect(RailsStructuredLogging.enabled?).to be true
      configuration = RailsStructuredLogging.configuration
      expect(configuration.enabled).to eq(enabled)
      expect(configuration.lograge_enabled).to eq(lograge_enabled)
      expect(configuration.logstop_email_salt).to eq(logstop_email_salt)
      expect(configuration.filter_emails).to eq(filter_emails)
      expect(configuration.filter_credit_cards).to eq(filter_credit_cards)
    end
  end

  describe "LogstopFork with Sorbet type signatures" do
    sig { returns(String) }
    let(:email) { "test@example.com" }

    it "scrubs sensitive information" do
      result = RailsStructuredLogging::LogstopFork.scrub(email)

      # Verify email was scrubbed
      expect(result).not_to include(email)
      expect(result).to include("[EMAIL:")
    end
  end

  describe "LogFormatter with Sorbet type signatures" do
    sig { returns(String) }
    let(:test_message) { "Test message" }

    sig { returns(Time) }
    let(:test_time) { Time.now }

    sig { returns(RailsStructuredLogging::LogFormatter) }
    let(:formatter) { RailsStructuredLogging::LogFormatter.new }

    it "formats log messages" do
      result = formatter.call("INFO", test_time, nil, test_message)

      # Verify JSON formatting
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
      expect(JSON.parse(result)["msg"]).to eq(test_message)
    end
  end
end
