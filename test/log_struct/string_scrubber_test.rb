# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class StringScrubberTest < ActiveSupport::TestCase
    def setup
      # Save original configuration
      @original_config = LogStruct::Configuration.instance

      # Create a new configuration for testing
      test_config = LogStruct::Configuration.new(
        filters: ConfigStruct::Filters.new(
          email_addresses: true,
          url_passwords: true,
          credit_card_numbers: true,
          phone_numbers: true,
          ssns: true,
          ip_addresses: true,
          mac_addresses: true,
          hash_salt: "test_salt",
          hash_length: 8
        ),
        string_scrubbing_handler: nil
      )

      # Replace the configuration
      LogStruct.configuration = test_config
    end

    def teardown
      # Restore original configuration
      LogStruct.configuration = @original_config
    end

    def test_scrub_email_addresses
      # Test with a simple email
      input = "Contact us at user@example.com for more information"
      result = StringScrubber.scrub(input)

      # Verify the email was replaced with a hash
      assert_not_includes result, "user@example.com"
      assert_match(/\[EMAIL:[a-f0-9]+\]/, result)

      # Test with multiple emails
      input = "Emails: user1@example.com and user2@example.org"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "user1@example.com"
      assert_not_includes result, "user2@example.org"
      assert_match(/\[EMAIL:[a-f0-9]+\].*\[EMAIL:[a-f0-9]+\]/, result)
    end

    def test_scrub_url_passwords
      # Test with a URL containing a password
      # cspell:ignore mydb
      input = "Database URL: postgres://user:password123@localhost:5432/mydb"
      result = StringScrubber.scrub(input)

      # Verify the password was filtered
      assert_not_includes result, "password123"
      assert_includes result, "postgres://user:[FILTERED]@localhost:5432/mydb"

      # Test with encoded URL
      # cspell:ignore Fuser Asecret
      input = "Encoded URL: https%3A%2F%2Fuser%3Asecret%40example.com"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "secret"
      assert_includes result, "[FILTERED]"
    end

    def test_scrub_credit_card_numbers
      # Test with a 16-digit card number
      input = "Card: 4111111111111111"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "4111111111111111"
      assert_includes result, "[CREDIT_CARD]"

      # Test with formatted card number
      input = "Card: 4111-1111-1111-1111"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "4111-1111-1111-1111"
      assert_includes result, "[CREDIT_CARD]"
    end

    def test_scrub_phone_numbers
      # Test with a formatted phone number
      input = "Call us at 555-123-4567"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "555-123-4567"
      assert_includes result, "[PHONE]"
    end

    def test_scrub_ssns
      # Test with a formatted SSN
      input = "SSN: 123-45-6789"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "123-45-6789"
      assert_includes result, "[SSN]"
    end

    def test_scrub_ip_addresses
      # Test with an IP address
      input = "IP: 192.168.1.1"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "192.168.1.1"
      assert_includes result, "[IP]"
    end

    def test_scrub_mac_addresses
      # Test with a MAC address
      input = "MAC: 00:11:22:33:44:55"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "00:11:22:33:44:55"
      assert_includes result, "[MAC]"
    end

    def test_disabled_filters
      # Create a config with all filters disabled
      test_config = LogStruct::Configuration.new(
        filters: ConfigStruct::Filters.new(
          email_addresses: false,
          url_passwords: false,
          credit_card_numbers: false,
          phone_numbers: false,
          ssns: false,
          ip_addresses: false,
          mac_addresses: false
        )
      )
      LogStruct.configuration = test_config

      # Test with sensitive data
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567"
      result = StringScrubber.scrub(input)

      # Verify nothing was filtered
      assert_equal input, result
    end

    def test_custom_scrubbing_handler
      # Create a config with custom handler
      custom_handler = ->(msg) { msg.gsub("SECRET", "[REDACTED]") }
      test_config = LogStruct::Configuration.new(
        filters: LogStruct.config.filters,
        string_scrubbing_handler: custom_handler
      )
      LogStruct.configuration = test_config

      # Test with custom data
      input = "This contains a SECRET value"
      result = StringScrubber.scrub(input)

      # Verify custom scrubbing was applied
      assert_not_includes result, "SECRET"
      assert_includes result, "[REDACTED]"
    end

    def test_multiple_filters
      # Test with multiple sensitive data types
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567"
      result = StringScrubber.scrub(input)

      # Verify all sensitive data was filtered
      assert_not_includes result, "user@example.com"
      assert_not_includes result, "4111111111111111"
      assert_not_includes result, "555-123-4567"
      assert_match(/\[EMAIL:[a-f0-9]{8,}\]/, result)
      assert_includes result, "[CREDIT_CARD]"
      assert_includes result, "[PHONE]"
    end
  end
end
