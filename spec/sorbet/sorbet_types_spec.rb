# typed: strict
# frozen_string_literal: true

require "spec_helper"

# This spec file shows how we can use Sorbet type signatures in RSpec tests.
# See: https://github.com/FooBarWidget/rspec-sorbet-types

RSpec.describe "Sorbet Types" do
  T.bind(self, T.class_of(RSpec::ExampleGroups::SorbetTypes))
  extend RSpec::Sorbet::Types::Sig

  rsig { returns(T::Boolean) }
  let(:enabled) { true }

  rsig { returns(T::Boolean) }
  let(:lograge_enabled) { true }

  rsig { returns(String) }
  let(:email_hashing_salt) { "test_salt" }

  rsig { returns(T::Boolean) }
  let(:filter_emails) { true }

  rsig { returns(T::Boolean) }
  let(:filter_credit_cards) { true }

  it "passes typechecking for the enabled variable" do
    expect(enabled).to be true
  end

  describe "Configuration with Sorbet type signatures" do
    before do
      # Demonstrate that typechecking works in before blocks
      email_hashing_salt.upcase
    end

    it "configures the gem with type-checked methods" do
      LogStruct.configure do |config|
        config.enabled = enabled
        config.lograge_enabled = lograge_enabled
        config.email_hashing_salt = email_hashing_salt
        config.filter_emails = filter_emails
        config.filter_credit_cards = filter_credit_cards
      end

      # Verify configuration was applied
      expect(LogStruct.enabled?).to be true
      configuration = LogStruct.configuration
      expect(configuration.enabled).to eq(enabled)
      expect(configuration.lograge_enabled).to eq(lograge_enabled)
      expect(configuration.email_hashing_salt).to eq(email_hashing_salt)
      expect(configuration.filter_emails).to eq(filter_emails)
      expect(configuration.filter_credit_cards).to eq(filter_credit_cards)
    end
  end

  describe "LogstopFork with Sorbet type signatures" do
    T.bind(self, T.class_of(RSpec::ExampleGroups::SorbetTypes::LogstopForkWithSorbetTypeSignatures))
    rsig { returns(String) }
    let(:email) { "test@example.com" }

    it "scrubs sensitive information" do
      result = LogStruct::LogstopFork.scrub(email)

      # Verify email was scrubbed
      expect(result).not_to include(email)
      expect(result).to include("[EMAIL:")
    end
  end

  describe "JSONFormatter with Sorbet type signatures" do
    T.bind(self, T.class_of(RSpec::ExampleGroups::SorbetTypes::JSONFormatterWithSorbetTypeSignatures))

    rsig { returns(String) }
    let(:test_message) { "Test message" }

    rsig { returns(Time) }
    let(:test_time) { Time.zone.now }

    rsig { returns(LogStruct::JSONFormatter) }
    let(:formatter) { LogStruct::JSONFormatter.new }

    it "formats log messages" do
      result = formatter.call("INFO", test_time, nil, test_message)

      # Verify JSON formatting
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
      expect(JSON.parse(result)["msg"]).to eq(test_message)
    end
  end
end
