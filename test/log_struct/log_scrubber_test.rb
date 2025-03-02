# typed: false
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class LogScrubberTest < Minitest::Test
    def setup
      # Save original configuration
      @original_config = LogStruct.configuration

      # Create a fresh configuration for each test
      LogStruct.configuration = Configuration.new
    end

    def teardown
      # Restore original configuration
      LogStruct.configuration = @original_config
    end

    def test_scrub_email_addresses
      # Enable email filtering
      LogStruct.config.filter_emails = true
      LogStruct.config.email_hash_salt = "test_salt"
      LogStruct.config.email_hash_length = 8

      # Test with a simple email
      input = "Contact us at user@example.com for more information"
      result = LogScrubber.scrub(input)

      # Verify the email was replaced with a hash
      assert_not_includes result, "user@example.com"
      assert_match(/\[EMAIL:[a-f0-9]{8}\]/, result)

      # Test with multiple emails
      input = "Emails: user1@example.com and user2@example.org"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "user1@example.com"
      assert_not_includes result, "user2@example.org"
      assert_match(/\[EMAIL:[a-f0-9]{8}\].*\[EMAIL:[a-f0-9]{8}\]/, result)
    end

    def test_scrub_url_passwords
      # Enable URL password filtering
      LogStruct.config.filter_url_passwords = true

      # Test with a URL containing a password
      input = "Database URL: postgres://user:password123@localhost:5432/mydb"
      result = LogScrubber.scrub(input)

      # Verify the password was filtered
      assert_not_includes result, "password123"
      assert_includes result, "postgres://user:[FILTERED]@localhost:5432/mydb"

      # Test with encoded URL
      input = "Encoded URL: https%3A%2F%2Fuser%3Asecret%40example.com"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "secret"
      assert_includes result, "[FILTERED]"
    end

    def test_scrub_credit_card_numbers
      # Enable credit card filtering
      LogStruct.config.filter_credit_cards = true

      # Test with a 16-digit card number
      input = "Card: 4111111111111111"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "4111111111111111"
      assert_includes result, "[CREDIT_CARD]"

      # Test with formatted card number
      input = "Card: 4111-1111-1111-1111"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "4111-1111-1111-1111"
      assert_includes result, "[CREDIT_CARD]"
    end

    def test_scrub_phone_numbers
      # Enable phone number filtering
      LogStruct.config.filter_phones = true

      # Test with a formatted phone number
      input = "Call us at 555-123-4567"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "555-123-4567"
      assert_includes result, "[PHONE]"
    end

    def test_scrub_ssns
      # Enable SSN filtering
      LogStruct.config.filter_ssns = true

      # Test with a formatted SSN
      input = "SSN: 123-45-6789"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "123-45-6789"
      assert_includes result, "[SSN]"
    end

    def test_scrub_ip_addresses
      # Enable IP filtering
      LogStruct.config.filter_ips = true

      # Test with an IP address
      input = "IP: 192.168.1.1"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "192.168.1.1"
      assert_includes result, "[IP]"
    end

    def test_scrub_mac_addresses
      # Enable MAC filtering
      LogStruct.config.filter_macs = true

      # Test with a MAC address
      input = "MAC: 00:11:22:33:44:55"
      result = LogScrubber.scrub(input)

      assert_not_includes result, "00:11:22:33:44:55"
      assert_includes result, "[MAC]"
    end

    def test_disabled_filters
      # Disable all filters
      LogStruct.config.filter_emails = false
      LogStruct.config.filter_url_passwords = false
      LogStruct.config.filter_credit_cards = false
      LogStruct.config.filter_phones = false
      LogStruct.config.filter_ssns = false
      LogStruct.config.filter_ips = false
      LogStruct.config.filter_macs = false

      # Test with sensitive data
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567"
      result = LogScrubber.scrub(input)

      # Verify nothing was filtered
      assert_equal input, result
    end

    def test_custom_scrubbing_handler
      # Set a custom scrubbing handler
      LogStruct.config.log_scrubbing_handler = ->(msg) { msg.gsub("SECRET", "[REDACTED]") }

      # Test with custom data
      input = "This contains a SECRET value"
      result = LogScrubber.scrub(input)

      # Verify custom scrubbing was applied
      assert_not_includes result, "SECRET"
      assert_includes result, "[REDACTED]"
    end

    def test_multiple_filters
      # Enable multiple filters
      LogStruct.config.filter_emails = true
      LogStruct.config.filter_credit_cards = true
      LogStruct.config.filter_phones = true

      # Test with multiple sensitive data types
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567"
      result = LogScrubber.scrub(input)

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
